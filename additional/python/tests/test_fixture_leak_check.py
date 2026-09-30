"""Leak check for the shared fixtures in test/fixtures/.

The zorin_*.txt fixtures are real command outputs captured on a developer
machine and redacted by hand at capture time. This test is the safety net
that runs in CI: if a future capture ships with a private IP, a named home
directory, a real URL/domain, a user@host pair or a port in an unambiguous
form (port=/port:, host:port), the suite fails before it reaches the public
repository.

The check is heuristic — it complements, never replaces, the manual review
documented in test/fixtures/README.md.
"""

import os
import re
import unittest

# additional/python/tests/ -> repo root: four dirname levels (tests, python,
# additional, root).
REPO_ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
)
FIXTURE_DIR = os.path.join(REPO_ROOT, "test", "fixtures")

# Public suffixes considered harmless in fixtures. Anything else that looks
# like a dotted host is flagged.
ALLOWED_TLDS = r"com|net|org|io|dev|de|eu|info|biz|co|me|app|xyz|example"

# The one allowed URL placeholder; findings that point at it are dropped.
ALLOWED_URL = "example.invalid"

_IPV4_OCTET = r"(?:25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])"

_PATTERNS = (
    # 1. IPv4: four 0-255 octets, not embedded in a longer dotted token
    #    (keeps version strings like 1.2.3.4.5 and host names like a.b.c.d
    #    that carry a trailing label out of the match).
    re.compile(
        r"(?<![\w.])" + _IPV4_OCTET + r"(?:\." + _IPV4_OCTET + r"){3}(?![\w.])"
    ),
    # 3. /home/<x> and /media/<x> with x != 'user' — 'user' is the only
    #    name the redaction rules keep.
    re.compile(r"/(?:home|media)/(?!user\b)[^/\s]+"),
    # 4. URL/domain with a TLD from the allowlist.
    re.compile(r"[a-zA-Z0-9][a-zA-Z0-9.-]*\.(?:" + ALLOWED_TLDS + r")\b"),
    # 5. user@host
    re.compile(r"[A-Za-z0-9._-]+@[a-zA-Z0-9][a-zA-Z0-9.-]*\b"),
    # 7. port in the unambiguous port= / port: forms (--port=41641,
    #    port: 5432). The space form (--port 7000) stays out on purpose:
    #    it is indistinguishable from ordinary argument values.
    re.compile(r"(?i)\bport\s*[=:]\s*\d{1,5}\b"),
    # 8. host:port — hostname-like label run (letters, digits, hyphens,
    #    dots; no underscores) directly before the colon. The colon must
    #    not follow a digit or colon, so clock times (14:23:01, up 3:45)
    #    and kernel thread names (259:0) stay out; display numbers with no
    #    host (vnc=:0, Xwayland :1) and identifier handles with underscores
    #    (snapshot_data:100) have no hostname before the colon.
    re.compile(
        r"(?<![\w.-])"
        r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?"
        r"(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*"
        r"(?<![0-9:]):"
        r"\d{1,5}(?![\w.])"
    ),
)


def _ipv6_candidates(text):
    """Heuristic IPv6 hits: runs of hex digits and colons containing '::'.

    At least one decimal digit is required so that C++ scope separators
    (std::vector) stay out; real addresses like ::1 or 2001:db8::1 carry
    digits.
    """
    for run in re.findall(r"[0-9A-Fa-f:]+", text):
        if "::" in run and any(c.isdigit() for c in run):
            yield run


def find_leaks(text: str) -> list:
    """Return the findings in *text* as strings; an empty list means clean."""
    findings = []
    for pattern in _PATTERNS:
        findings.extend(pattern.findall(text))
    findings.extend(_ipv6_candidates(text))

    seen = set()
    unique = []
    for finding in findings:
        # 6. Post-filter: the allowed URL placeholder never counts as a leak.
        if ALLOWED_URL in finding:
            continue
        if finding not in seen:
            seen.add(finding)
            unique.append(finding)
    return unique


class LeakDetection(unittest.TestCase):
    MUST_FLAG = [
        "192.168.178.23",
        "2001:db8::1",
        "connect to 10.0.0.5:5432",
        "/home/bratan/secret.txt",
        "/media/braten/USB",
        "curl https://internal.corp.example/health",
        "ssh git@github.com",
        "port=5432",
        "port: 41641",
        "connect host:8080",
        "tcp:db-server.internal:7149",
    ]
    MUST_NOT_FLAG = [
        " 14:23:01 up  3:45,  1 user,  load average: 0.52, 0.58",
        "udev            7,8G     0  7,8G   0% /dev",
        "/usr/lib/firefox/firefox",
        "libGL.so.1",
        "python3.12",
        "/home/user/notes.txt",
        "/media/user/USB",
        "https://example.invalid/x",
        "/dev/nvme0n1p2",
        "%CPU COMMAND",
        "14:23:01 up 3:45",
        "0.52, 0.58",
        "--port 7000",
        "vnc=:0,websocket=5700",
        "Xwayland :1",
        "--shared-files=v8_context_snapshot_data:100",
    ]

    def test_every_must_flag_vector_is_detected(self):
        for vector in self.MUST_FLAG:
            self.assertTrue(find_leaks(vector), "not flagged: %r" % vector)

    def test_no_must_not_flag_vector_is_detected(self):
        for vector in self.MUST_NOT_FLAG:
            self.assertEqual(find_leaks(vector), [], "flagged: %r" % vector)


class FixturesClean(unittest.TestCase):
    """Every fixture under test/fixtures/ survives the leak check.

    Only *.txt files are scanned. README.md is deliberately excluded: it
    documents the redaction rules and the allowed placeholders, so it
    contains exactly the kinds of strings this check exists to catch and
    would fail by design.
    """

    ZORIN_FIXTURES = [
        "zorin_df.txt",
        "zorin_free.txt",
        "zorin_loadavg.txt",
        "zorin_ps.txt",
        "zorin_uptime.txt",
    ]

    def test_the_five_real_zorin_captures_exist(self):
        for name in self.ZORIN_FIXTURES:
            self.assertTrue(
                os.path.isfile(os.path.join(FIXTURE_DIR, name)),
                "missing fixture: %s" % name,
            )

    def test_every_txt_fixture_is_free_of_leaks(self):
        self.assertTrue(os.path.isdir(FIXTURE_DIR), "%s is missing" % FIXTURE_DIR)
        names = sorted(n for n in os.listdir(FIXTURE_DIR) if n.endswith(".txt"))
        self.assertTrue(names, "no *.txt fixtures under %s" % FIXTURE_DIR)
        for name in names:
            with open(os.path.join(FIXTURE_DIR, name), encoding="utf-8") as handle:
                content = handle.read()
            self.assertEqual(find_leaks(content), [], "%s contains leaks" % name)


if __name__ == "__main__":
    unittest.main()
