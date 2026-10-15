"""Prevent missing GPU evidence from being reported as a passing render contract."""
import unittest
from tools.hero_2d.check_hair_gpu import validate_cases


class HairGPUReceiptTest(unittest.TestCase):
    def cases(self):
        return [{"key":f"{view}-hat{int(hat)}","view":view,"hat":hat} for view in ["front","left"] for hat in [False,True]]

    def test_exact_four_configurations_are_required(self):
        self.assertEqual(validate_cases({"cases":self.cases()}),self.cases())

    def test_empty_missing_or_incomplete_evidence_fails(self):
        for receipt in [{},{"cases":[]},{"cases":self.cases()[:-1]}]:
            with self.subTest(receipt=receipt), self.assertRaises(ValueError):validate_cases(receipt)

    def test_duplicate_configuration_fails(self):
        cases=self.cases();cases[-1]=cases[0]
        with self.assertRaises(ValueError):validate_cases({"cases":cases})

    def test_label_cannot_hide_wrong_rendered_configuration(self):
        cases=self.cases();cases[-1]["hat"]=False
        with self.assertRaises(ValueError):validate_cases({"cases":cases})
