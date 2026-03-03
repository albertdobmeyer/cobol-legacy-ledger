"""
Tests for python.cobol_analyzer.cross_file -- multi-file COBOL analysis.

Verifies CALL_EXTERNAL, COPY_DEPENDENCY, and SHARED_COPYBOOK edge detection
across multiple COBOL source files.
"""

import pytest
from pathlib import Path
from python.cobol_analyzer.cross_file import CrossFileAnalyzer, CrossFileResult


# ── Minimal COBOL Snippets ──────────────────────────────────────

PROG_A = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROGA.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY 'SHARED.cpy'.
       01  WS-X  PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           CALL 'PROGB'
           STOP RUN.
"""

PROG_B = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROGB.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       COPY 'SHARED.cpy'.
       01  WS-Y  PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       ENTRY-PARA.
           DISPLAY "PROGB RUNNING"
           STOP RUN.
"""

PROG_C = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROGC.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-Z  PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       DO-WORK.
           CALL 'PROGA'
           CALL 'PROGB'
           STOP RUN.
"""

SINGLE_PROG = """\
       IDENTIFICATION DIVISION.
       PROGRAM-ID. SOLO.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01  WS-A  PIC 9 VALUE 0.
       PROCEDURE DIVISION.
       MAIN-PARA.
           DISPLAY "SOLO"
           STOP RUN.
"""


class TestCrossFileAnalyzer:
    def setup_method(self):
        self.analyzer = CrossFileAnalyzer()

    def test_call_external_edge(self):
        """CALL 'PROGB' in PROGA creates a CALL_EXTERNAL edge."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        call_edges = [e for e in result.cross_edges if e.edge_type == "CALL_EXTERNAL"]
        assert len(call_edges) >= 1
        assert any(
            e.source_file == "PROGA.cob" and e.target_file == "PROGB.cob"
            for e in call_edges
        )

    def test_call_external_target_program(self):
        """CALL_EXTERNAL edge stores the target program name."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        call_edges = [e for e in result.cross_edges if e.edge_type == "CALL_EXTERNAL"]
        assert any(e.target_program == "PROGB" for e in call_edges)

    def test_shared_copybook_edge(self):
        """Two programs COPYing the same copybook creates a SHARED_COPYBOOK edge."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        shared_edges = [e for e in result.cross_edges if e.edge_type == "SHARED_COPYBOOK"]
        assert len(shared_edges) >= 1
        files_in_edges = set()
        for e in shared_edges:
            files_in_edges.add(e.source_file)
            files_in_edges.add(e.target_file)
        assert "PROGA.cob" in files_in_edges
        assert "PROGB.cob" in files_in_edges

    def test_no_self_call_edge(self):
        """A file calling itself should not create a CALL_EXTERNAL edge."""
        # PROGA calls PROGB, not itself
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        self_edges = [
            e for e in result.cross_edges
            if e.source_file == e.target_file
        ]
        assert len(self_edges) == 0

    def test_multiple_calls_from_one_file(self):
        """PROGC calls both PROGA and PROGB -- two CALL_EXTERNAL edges."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B, "PROGC.cob": PROG_C}
        result = self.analyzer.analyze(sources)
        call_edges_from_c = [
            e for e in result.cross_edges
            if e.edge_type == "CALL_EXTERNAL" and e.source_file == "PROGC.cob"
        ]
        assert len(call_edges_from_c) == 2

    def test_single_file_no_cross_edges(self):
        """A single file with no CALL or shared COPY produces no cross-edges."""
        sources = {"SOLO.cob": SINGLE_PROG}
        result = self.analyzer.analyze(sources)
        assert len(result.cross_edges) == 0

    def test_file_nodes_created(self):
        """Each source file gets a FileNode in the result."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        assert "PROGA.cob" in result.files
        assert "PROGB.cob" in result.files

    def test_file_node_program_id(self):
        """FileNode extracts PROGRAM-ID correctly."""
        sources = {"PROGA.cob": PROG_A}
        result = self.analyzer.analyze(sources)
        assert result.files["PROGA.cob"].program_id == "PROGA"

    def test_total_lines(self):
        """total_lines accumulates across all files."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        assert result.total_lines > 0
        assert result.total_lines == PROG_A.count('\n') + 1 + PROG_B.count('\n') + 1

    def test_to_dict_structure(self):
        """to_dict() returns all expected top-level keys."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        d = result.to_dict()
        assert "files" in d
        assert "cross_edges" in d
        assert "per_file_graphs" in d
        assert "per_file_complexity" in d
        assert "total_paragraphs" in d
        assert "total_lines" in d
        assert "total_complexity" in d

    def test_to_dict_cross_edges_serialized(self):
        """to_dict() serializes cross-edges as dicts with correct keys."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        d = result.to_dict()
        for edge in d["cross_edges"]:
            assert "source_file" in edge
            assert "target_file" in edge
            assert "edge_type" in edge

    def test_shared_copybook_deduplication(self):
        """Same copybook shared by A and B should produce exactly one SHARED_COPYBOOK edge."""
        sources = {"PROGA.cob": PROG_A, "PROGB.cob": PROG_B}
        result = self.analyzer.analyze(sources)
        shared_edges = [e for e in result.cross_edges if e.edge_type == "SHARED_COPYBOOK"]
        # Only one pair (A, B) for SHARED copybook
        pairs = {tuple(sorted([e.source_file, e.target_file])) for e in shared_edges}
        assert len(pairs) == 1


# ── Real Payroll File Tests ─────────────────────────────────────

PAYROLL_SRC = Path(__file__).resolve().parent.parent.parent / "COBOL-BANKING" / "payroll" / "src"


@pytest.mark.skipif(
    not PAYROLL_SRC.exists(),
    reason="Payroll source directory not found",
)
class TestCrossFilePayroll:
    """Cross-file analysis on real payroll spaghetti programs."""

    def _load_sources(self):
        sources = {}
        for f in PAYROLL_SRC.glob("*.cob"):
            sources[f.name] = f.read_text(encoding="utf-8", errors="replace")
        return sources

    def test_payroll_file_count(self):
        sources = self._load_sources()
        assert len(sources) == 8, f"Expected 8 payroll programs, found {len(sources)}"

    def test_payroll_cross_edges_exist(self):
        """8 payroll programs sharing copybooks should produce cross-edges."""
        sources = self._load_sources()
        result = CrossFileAnalyzer().analyze(sources)
        assert len(result.cross_edges) >= 5, (
            f"Expected >=5 cross-edges from 8 programs, got {len(result.cross_edges)}"
        )

    def test_payroll_shared_copybook_edges(self):
        """Programs sharing PAYCOM.cpy or EMPREC.cpy produce SHARED_COPYBOOK edges."""
        sources = self._load_sources()
        result = CrossFileAnalyzer().analyze(sources)
        shared = [e for e in result.cross_edges if e.edge_type == "SHARED_COPYBOOK"]
        assert len(shared) >= 1

    def test_payroll_total_complexity_spaghetti(self):
        """Combined payroll complexity should be very high."""
        sources = self._load_sources()
        result = CrossFileAnalyzer().analyze(sources)
        assert result.total_complexity >= 50
