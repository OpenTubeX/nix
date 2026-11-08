import copy
import json
from pathlib import Path
import unittest

from update import release_metadata


class ReleaseMetadataTests(unittest.TestCase):
    def setUp(self):
        pin = json.loads((Path(__file__).resolve().parents[1] / "release.json").read_text())
        self.current = pin["version"]
        self.release = {
            "tag_name": pin["tag"], "draft": False, "prerelease": False,
            "assets": [{"name": source["name"], "digest": "sha256:" + "ab" * 32}
                       for source in pin["sources"].values()],
        }

    def test_all_platforms_and_sri_hashes(self):
        metadata = release_metadata(self.release, self.current)
        self.assertEqual(set(metadata["sources"]), {
            "aarch64-linux", "x86_64-linux", "aarch64-darwin", "x86_64-darwin",
        })
        for source in metadata["sources"].values():
            self.assertEqual(source["hash"], "sha256-q6urq6urq6urq6urq6urq6urq6urq6urq6urq6urq6s=")

    def test_rejects_missing_platform(self):
        self.release["assets"].pop()
        with self.assertRaisesRegex(ValueError, "exactly one"):
            release_metadata(self.release, self.current)

    def test_rejects_duplicate_asset(self):
        self.release["assets"].append(self.release["assets"][0])
        with self.assertRaisesRegex(ValueError, "exactly one"):
            release_metadata(self.release, self.current)

    def test_rejects_missing_or_invalid_digests(self):
        for digest in [None, "", "sha256:abc", "sha512:" + "ab" * 32, "sha256:" + "zz" * 32]:
            with self.subTest(digest=digest):
                self.release["assets"][0]["digest"] = digest
                with self.assertRaisesRegex(ValueError, "SHA-256"):
                    release_metadata(self.release, self.current)

    def test_rejects_nightly_draft_and_prerelease(self):
        for change in [{"tag_name": "nightly"}, {"tag_name": "v1.2.3/../../latest"},
                       {"draft": True}, {"prerelease": True}]:
            with self.subTest(change=change):
                release = self.release | change
                with self.assertRaisesRegex(ValueError, "published stable"):
                    release_metadata(release, self.current)

    def test_rejects_downgrade(self):
        with self.assertRaisesRegex(ValueError, "downgrade"):
            release_metadata(self.release, "99.0.0-beta")
        with self.assertRaisesRegex(ValueError, "downgrade"):
            release_metadata(self.release, self.current.removesuffix("-beta"))
        self.assertEqual(release_metadata(self.release, "0.0.1")["version"], self.current)

    def test_supports_release_without_beta_suffix(self):
        release = copy.deepcopy(self.release)
        release["tag_name"] = release["tag_name"].removesuffix("-beta")
        for asset in release["assets"]:
            asset["name"] = asset["name"].replace("-beta", "").replace("_beta", "")
        metadata = release_metadata(release, self.current)
        self.assertNotIn("beta", metadata["version"])


if __name__ == "__main__":
    unittest.main()
