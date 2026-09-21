"""Independent physical limits and statistical consistency checks. Run: python -m unittest -v."""
import copy
import unittest
import numpy as np
from dps_qkd import (default_parameters, simulate, channel_model, draw_channel,
                    encode_bytes, validate, turbulence_parameters, wilson)


class PhysicsTests(unittest.TestCase):
    def setUp(self):
        self.p=default_parameters()
        self.p.update(n_slots=100000,visibility=1.0,phase_sigma_rad=0.0,
                      dark_hz=0.0,background_hz=0.0)

    def test_encoding(self):
        self.assertEqual(encode_bytes('A5').Alice_key_bit.tolist(),[1,1,1,0,1,1,1])

    def test_ideal_click_rate_has_no_half_sifting(self):
        r=simulate(self.p); c=r['channel']
        mean=self.p['mu']*c['eta0']*c['gate_capture']*self.p['detector_eta']*self.p['coupling_eta']*10**(-self.p['interferometer_loss_db']/10)
        self.assertAlmostEqual(r['summary']['expected_single_probability'],1-np.exp(-mean),13)
        self.assertEqual(r['summary']['qber_model'],0.0)
        self.assertEqual(r['summary']['errors'],0)

    def test_zero_signal_no_noise_is_undefined_qber(self):
        self.p['mu']=0
        s=simulate(self.p)['summary']
        self.assertEqual(s['detected_sifted_bits'],0)
        self.assertTrue(np.isnan(s['qber_observed']))
        self.assertEqual(s['illustrative_postprocessing_bps'],0)

    def test_noise_only_expected_qber_and_singles(self):
        self.p.update(mu=0.0,dark_hz=1e8)
        s=simulate(self.p)['summary']; x=1-np.exp(-self.p['dark_hz']*self.p['gate_ns']*1e-9)
        self.assertAlmostEqual(s['qber_model'],.5,13)
        self.assertAlmostEqual(s['expected_single_probability'],2*x*(1-x),13)
        self.assertGreater(s['double_clicks'],0)

    def test_zenith_range_and_monotonic_airmass(self):
        self.p.update(channel='Satellite-Ground',elevation_deg=90.0)
        high=channel_model(self.p)
        self.assertAlmostEqual(high['length_m'],self.p['sat_altitude_km']*1000,7)
        self.p['elevation_deg']=15
        low=channel_model(self.p)
        self.assertGreater(low['length_m'],high['length_m'])
        self.assertGreater(low['rytov'],high['rytov'])
        self.assertGreater(low['total_loss_db'],high['total_loss_db'])

    def test_opaque_cloud(self):
        self.p.update(channel='Satellite-Ground',cloud_probability=1.0,dark_hz=1000.0)
        r=simulate(self.p)
        self.assertTrue(np.all(r['fading']['eta']==0))
        self.assertAlmostEqual(r['summary']['qber_model'],.5,13)

    def test_turbulence_disabled(self):
        self.p.update(channel='FSO-Terrestrial',fso_cn2=0.0)
        r=simulate(self.p)
        self.assertTrue(np.all(r['fading']['fade']==1))
        self.assertTrue(np.isinf(r['channel']['r0']))

    def test_same_fading_preserves_interference_inside_block(self):
        self.p.update(channel='FSO-Terrestrial')
        t=simulate(self.p)['trace']
        equal=t.eta_previous==t.eta_current
        wrong=np.where(t.alice_bit==0,t.nu1,t.nu0)
        self.assertLess(np.max(wrong[equal]),1e-14)

    def test_phase_resend_expected_disturbance(self):
        self.p.update(eve_mode='phase-resend',eve_fraction=1.0,n_slots=400000)
        r=simulate(self.p)
        self.assertAlmostEqual(r['summary']['qber_model'],r['eve']['expected_signal_qber'],delta=.004)

    def test_beam_split_changes_power_not_ideal_signal_qber(self):
        base=simulate(self.p)
        self.p.update(eve_mode='beam-split',eve_tap=.5)
        r=simulate(self.p)
        self.assertEqual(r['summary']['qber_model'],0)
        self.assertLess(r['summary']['sifted_rate_model_bps'],base['summary']['sifted_rate_model_bps'])
        self.assertGreater(r['summary']['eve_estimated_sifted_bits'],0)
        self.p['eve_tap']=1
        self.assertEqual(simulate(self.p)['summary']['detected_sifted_bits'],0)

    def test_seed_repeatability(self):
        self.p.update(channel='FSO-Terrestrial',fading_model='gamma-gamma')
        a=simulate(self.p); b=simulate(self.p)
        np.testing.assert_array_equal(a['trace'].to_numpy(),b['trace'].to_numpy())

    def test_gamma_gamma_moments(self):
        self.p.update(channel='FSO-Terrestrial',n_slots=200000,block_slots=1,fading_model='gamma-gamma')
        c=channel_model(self.p); f=draw_channel(self.p,c,np.random.default_rng(10))
        self.assertAlmostEqual(np.mean(f['fade']),1,delta=.015)
        self.assertAlmostEqual(np.var(f['fade']),c['si'],delta=.05)

    def test_lognormal_moments(self):
        self.p.update(channel='FSO-Terrestrial',n_slots=200000,block_slots=1,fading_model='lognormal',fso_cn2=1e-15)
        c=channel_model(self.p); f=draw_channel(self.p,c,np.random.default_rng(10))
        self.assertAlmostEqual(np.mean(f['fade']),1,delta=.006)
        self.assertAlmostEqual(np.var(f['fade']),np.expm1(c['rytov']),delta=.005)

    def test_dead_time_event_spacing_and_model(self):
        self.p.update(dead_time_ns=100.0,n_slots=500000)
        r=simulate(self.p); slots=r['trace'].loc[r['trace'].accepted,'slot'].to_numpy()
        self.assertTrue(np.all(np.diff(slots)>100))
        s=r['summary']
        self.assertAlmostEqual(s['sifted_rate_observed_bps']/s['sifted_rate_model_bps'],1,delta=.08)

    def test_validation_and_zero_trial_interval(self):
        for key,value in [('channel','unknown'),('eve_fraction',1.1),('seed',1.5),('gate_ns',2),('mu',float('nan')),('sample_hex','100')]:
            p=copy.deepcopy(self.p); p[key]=value
            with self.assertRaises(ValueError,msg=key): validate(p)
        self.assertTrue(np.isnan(wilson(0,0)[0]))


if __name__=='__main__': unittest.main()
