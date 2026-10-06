import unittest

from inspect_ios_signing import validate
from prepare_ios_entitlements import resolve


class SigningTests(unittest.TestCase):
    def test_nested_build_settings_resolve_without_changing_other_values(self):
        source = {
            "keychain-access-groups": ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"],
            "com.apple.developer.applesignin": ["Default"],
            "nested": {"enabled": True, "count": 2},
        }
        result = resolve(source, "TEAM123", "com.example.app")
        self.assertEqual(result["keychain-access-groups"], ["TEAM123.com.example.app"])
        self.assertEqual(result["com.apple.developer.applesignin"], ["Default"])
        self.assertEqual(result["nested"], source["nested"])
        self.assertIn("$(", source["keychain-access-groups"][0])

    def test_unknown_build_setting_fails_before_signing(self):
        for value in ["$(Unknown)", "${Unknown}"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                resolve({"entitlement": [value]}, "TEAM123", "com.example.app")

    def valid_report(self):
        return {
            "bundleId": "com.example.app",
            "signedAppleSignIn": ["Default"],
            "profileAppleSignIn": ["Default"],
            "signedTeam": "TEAM123",
            "profileTeam": "TEAM123",
            "signedApplicationId": "TEAM123.com.example.app",
            "profileApplicationId": "TEAM123.com.example.app",
            "signedKeychainGroups": ["TEAM123.com.example.app"],
            "signedDebuggable": False,
        }

    def test_distribution_identity_and_apple_permissions_pass(self):
        self.assertEqual(validate(self.valid_report(), "TEAM123", "com.example.app"), [])

    def test_missing_permission_or_wrong_identity_blocks_upload(self):
        mutations = {
            "signedAppleSignIn": [],
            "profileAppleSignIn": [],
            "bundleId": "com.other.app",
            "signedTeam": "OTHER",
            "profileTeam": "OTHER",
            "signedApplicationId": "TEAM123.com.other.app",
            "profileApplicationId": "TEAM123.*",
            "signedKeychainGroups": [],
            "signedDebuggable": True,
        }
        for field, wrong_value in mutations.items():
            for value in [wrong_value, None]:
                with self.subTest(field=field, value=value):
                    report = self.valid_report()
                    if value is None:
                        del report[field]
                    else:
                        report[field] = value
                    self.assertTrue(validate(report, "TEAM123", "com.example.app"))


if __name__ == "__main__":
    unittest.main()
