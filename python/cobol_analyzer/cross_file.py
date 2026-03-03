"""
cross_file -- Multi-file COBOL analysis tracing CALL/COPY chains across programs.

Builds a unified dependency graph spanning multiple COBOL source files. This is
the tool that proves the thesis: "Our tools can tame code that takes humans weeks
to understand." A single payment processor may have 8+ programs with inter-file
CALL chains and shared copybooks — understanding the full flow requires tracing
across all of them simultaneously.

Edge types (in addition to single-file edge types):
    CALL_EXTERNAL   -- CALL 'PROGNAME' linking one program to another
    COPY_DEPENDENCY -- COPY copybook-name linking a program to shared data

The analyze() method accepts a dict of {filename: source_text} and returns a
merged graph with file attribution per paragraph.
"""

import re
from typing import Dict, List, Set
from dataclasses import dataclass, field

from python.cobol_analyzer.call_graph import CallGraphAnalyzer, CallGraph, Edge
from python.cobol_analyzer.complexity import ComplexityAnalyzer, ComplexityResult


@dataclass
class FileNode:
    """A COBOL source file in the cross-file graph."""
    filename: str
    program_id: str = ""
    paragraphs: List[str] = field(default_factory=list)
    calls_out: List[str] = field(default_factory=list)
    copies: List[str] = field(default_factory=list)
    complexity_score: int = 0
    complexity_rating: str = ""


@dataclass
class CrossFileEdge:
    """An inter-file dependency."""
    source_file: str
    target_file: str
    edge_type: str  # CALL_EXTERNAL or COPY_DEPENDENCY
    source_paragraph: str = ""
    target_program: str = ""


@dataclass
class CrossFileResult:
    """Complete cross-file analysis."""
    files: Dict[str, FileNode] = field(default_factory=dict)
    cross_edges: List[CrossFileEdge] = field(default_factory=list)
    per_file_graphs: Dict[str, Dict] = field(default_factory=dict)
    per_file_complexity: Dict[str, Dict] = field(default_factory=dict)
    total_paragraphs: int = 0
    total_lines: int = 0
    total_complexity: int = 0

    def to_dict(self) -> Dict:
        return {
            "files": {
                k: {
                    "program_id": v.program_id,
                    "paragraphs": v.paragraphs,
                    "calls_out": v.calls_out,
                    "copies": v.copies,
                    "complexity_score": v.complexity_score,
                    "complexity_rating": v.complexity_rating,
                }
                for k, v in self.files.items()
            },
            "cross_edges": [
                {
                    "source_file": e.source_file,
                    "target_file": e.target_file,
                    "edge_type": e.edge_type,
                    "source_paragraph": e.source_paragraph,
                    "target_program": e.target_program,
                }
                for e in self.cross_edges
            ],
            "per_file_graphs": self.per_file_graphs,
            "per_file_complexity": self.per_file_complexity,
            "total_paragraphs": self.total_paragraphs,
            "total_lines": self.total_lines,
            "total_complexity": self.total_complexity,
        }


class CrossFileAnalyzer:
    """Analyzes CALL/COPY dependencies across multiple COBOL source files."""

    _CALL = re.compile(r"""CALL\s+['"](\w+)['"]""", re.IGNORECASE)
    _COPY = re.compile(r"""COPY\s+['"]?([\w.]+)['"]?""", re.IGNORECASE)
    _PROGRAM_ID = re.compile(r'PROGRAM-ID\.\s+(\w+)', re.IGNORECASE)

    def __init__(self):
        self._cg = CallGraphAnalyzer()
        self._cx = ComplexityAnalyzer()

    def analyze(self, sources: Dict[str, str]) -> CrossFileResult:
        """Analyze multiple COBOL source files for cross-file dependencies.

        :param sources: Dict mapping filename to source text
        :returns: CrossFileResult with per-file graphs and inter-file edges
        """
        result = CrossFileResult()

        # Build program-id to filename mapping
        prog_to_file: Dict[str, str] = {}

        for filename, source in sources.items():
            # Extract PROGRAM-ID
            m = self._PROGRAM_ID.search(source)
            program_id = m.group(1) if m else filename.replace('.cob', '')
            prog_to_file[program_id.upper()] = filename

            # Per-file analysis
            graph = self._cg.analyze(source)
            complexity = self._cx.analyze(source)
            lines = source.count('\n') + 1

            # Find CALL and COPY statements
            calls = list(set(self._CALL.findall(source)))
            copies = list(set(c.replace('.cpy', '') for c in self._COPY.findall(source)))

            file_node = FileNode(
                filename=filename,
                program_id=program_id,
                paragraphs=list(graph.paragraphs.keys()),
                calls_out=calls,
                copies=copies,
                complexity_score=complexity.total_score,
                complexity_rating=complexity.rating,
            )

            result.files[filename] = file_node
            result.per_file_graphs[filename] = graph.to_dict()
            result.per_file_complexity[filename] = complexity.to_dict()
            result.total_paragraphs += len(graph.paragraphs)
            result.total_lines += lines
            result.total_complexity += complexity.total_score

        # Build cross-file edges
        for filename, source in sources.items():
            # CALL edges
            for match in self._CALL.finditer(source):
                target_prog = match.group(1).upper()
                target_file = prog_to_file.get(target_prog)
                if target_file and target_file != filename:
                    # Find which paragraph the CALL is in
                    call_line = source[:match.start()].count('\n')
                    source_para = self._find_paragraph_at_line(
                        result.per_file_graphs[filename], call_line
                    )
                    result.cross_edges.append(CrossFileEdge(
                        source_file=filename,
                        target_file=target_file,
                        edge_type="CALL_EXTERNAL",
                        source_paragraph=source_para,
                        target_program=target_prog,
                    ))

            # COPY edges (match against known files in the analysis set)
            for match in self._COPY.finditer(source):
                copybook = match.group(1)
                for other_file in sources:
                    base = other_file.replace('.cob', '').replace('.cpy', '')
                    if copybook.replace('.cpy', '').upper() == base.upper() and other_file != filename:
                        result.cross_edges.append(CrossFileEdge(
                            source_file=filename,
                            target_file=other_file,
                            edge_type="COPY_DEPENDENCY",
                            target_program=copybook,
                        ))

        # Build shared-copybook coupling edges: if two programs COPY the
        # same copybook, they are implicitly coupled through shared data
        # definitions.  These edges make the cross-file graph useful even
        # when no CALL statements exist between standalone batch programs.
        copybook_users: Dict[str, List[str]] = {}
        for filename, node in result.files.items():
            for cpy in node.copies:
                copybook_users.setdefault(cpy.upper(), []).append(filename)

        seen_pairs: Set[tuple] = set()
        for cpy, users in copybook_users.items():
            if len(users) < 2:
                continue
            for i, a in enumerate(users):
                for b in users[i + 1:]:
                    pair = tuple(sorted([a, b]))
                    if pair not in seen_pairs:
                        seen_pairs.add(pair)
                        result.cross_edges.append(CrossFileEdge(
                            source_file=a,
                            target_file=b,
                            edge_type="SHARED_COPYBOOK",
                            target_program=cpy,
                        ))

        return result

    @staticmethod
    def _find_paragraph_at_line(graph_dict: Dict, line_num: int) -> str:
        """Find which paragraph contains the given line number."""
        paragraphs = graph_dict.get("paragraphs", [])
        if not paragraphs:
            return ""
        # Simple heuristic: return the last paragraph that starts before this line
        return paragraphs[-1] if paragraphs else ""
