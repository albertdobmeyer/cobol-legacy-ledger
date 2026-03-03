"""
complexity -- Per-paragraph complexity scoring for COBOL programs.

Assigns a complexity score to each paragraph based on the anti-patterns it
contains. Higher scores indicate more difficult-to-understand code.

Scoring weights (calibrated against real legacy COBOL):
    GO TO                +5   per occurrence (unconditional jump)
    ALTER                +10  per occurrence (runtime flow modification)
    PERFORM THRU         +3   per occurrence (range execution risk)
    Nested IF            +1   per nesting level (linear readability cost)
    EVALUATE             +1   per occurrence (structured, but adds paths)
    Dead code            +8   per dead paragraph (misleads readers)
    Magic number         +1   per occurrence (unnamed literal)
    CALL                 +2   per occurrence (inter-program coupling)
    COPY REPLACING       +4   per occurrence (namespace collision risk)
    SORT INPUT/OUTPUT    +6   per occurrence (callback-style flow)
    GO TO DEPENDING ON   +7   per occurrence (computed branch)
    Nested COPY          +5   per level (transitive dependency)
    INSPECT TALLYING     +1   per occurrence (string processing)

The overall program score is the sum of all paragraph scores. Programs
under 20 are "clean", 20-50 are "moderate legacy", 50+ are "spaghetti".
"""

import re
from typing import Dict, List
from dataclasses import dataclass, field


@dataclass
class ParagraphComplexity:
    """Complexity breakdown for a single paragraph."""
    name: str
    score: int = 0
    goto_count: int = 0
    alter_count: int = 0
    perform_thru_count: int = 0
    max_if_depth: int = 0
    evaluate_count: int = 0
    magic_number_count: int = 0
    call_count: int = 0
    copy_replacing_count: int = 0
    sort_procedure_count: int = 0
    goto_depending_count: int = 0
    inspect_tallying_count: int = 0
    line_count: int = 0
    factors: List[str] = field(default_factory=list)


@dataclass
class ComplexityResult:
    """Complete complexity analysis for a COBOL program."""
    paragraphs: Dict[str, ParagraphComplexity] = field(default_factory=dict)
    total_score: int = 0
    rating: str = ""  # "clean", "moderate", "spaghetti"

    def to_dict(self) -> Dict:
        return {
            "paragraphs": {
                k: {
                    "score": v.score, "goto": v.goto_count,
                    "alter": v.alter_count, "perform_thru": v.perform_thru_count,
                    "max_if_depth": v.max_if_depth, "evaluate": v.evaluate_count,
                    "magic_numbers": v.magic_number_count, "lines": v.line_count,
                    "call": v.call_count, "copy_replacing": v.copy_replacing_count,
                    "sort_procedure": v.sort_procedure_count,
                    "goto_depending": v.goto_depending_count,
                    "inspect_tallying": v.inspect_tallying_count,
                    "factors": v.factors,
                }
                for k, v in self.paragraphs.items()
            },
            "total_score": self.total_score,
            "rating": self.rating,
            "hotspots": sorted(
                [{"name": k, "score": v.score} for k, v in self.paragraphs.items()],
                key=lambda x: x["score"], reverse=True
            )[:5],
        }


class ComplexityAnalyzer:
    """Computes complexity scores for COBOL paragraphs."""

    _PARAGRAPH = re.compile(r'^(\s{4,8}[\w-]+)\.\s*$', re.MULTILINE)
    _COMMENT = re.compile(r'^\s*\*>')
    _GOTO = re.compile(r'GO\s+TO\s+', re.IGNORECASE)
    _ALTER = re.compile(r'ALTER\s+', re.IGNORECASE)
    _PERFORM_THRU = re.compile(r'PERFORM\s+\S+\s+THRU\s+', re.IGNORECASE)
    _EVALUATE = re.compile(r'EVALUATE\s+', re.IGNORECASE)
    _MAGIC_NUM = re.compile(r'(?<!\w)\d{4,}(?:\.\d+)?(?!\w)')  # Bare numbers (4+ digits only)
    _IF = re.compile(r'\bIF\b', re.IGNORECASE)
    _END_IF = re.compile(r'\bEND-IF\b', re.IGNORECASE)
    _CALL = re.compile(r'\bCALL\b', re.IGNORECASE)
    _COPY_REPLACING = re.compile(r'COPY\s+.*\s+REPLACING\b', re.IGNORECASE)
    _SORT_PROCEDURE = re.compile(r'\b(INPUT|OUTPUT)\s+PROCEDURE\b', re.IGNORECASE)
    _GOTO_DEPENDING = re.compile(r'GO\s+TO\s+.*\bDEPENDING\s+ON\b', re.IGNORECASE)
    _INSPECT_TALLYING = re.compile(r'INSPECT\s+.*\bTALLYING\b', re.IGNORECASE)

    def analyze(self, source: str) -> ComplexityResult:
        """Compute complexity scores for all paragraphs."""
        result = ComplexityResult()
        lines = source.split('\n')

        # Count file-level COPY REPLACING (outside PROCEDURE DIVISION)
        file_copy_replacing = 0
        for line in lines:
            if self._COPY_REPLACING.search(line):
                file_copy_replacing += 1

        current_para = None
        in_procedure = False
        para_lines: Dict[str, List[str]] = {}

        # Collect lines per paragraph
        for line in lines:
            if re.search(r'PROCEDURE\s+DIVISION', line, re.IGNORECASE):
                in_procedure = True
                continue
            if not in_procedure:
                continue

            match = self._PARAGRAPH.match(line)
            if match:
                current_para = match.group(1).strip()
                para_lines[current_para] = []
                continue

            if current_para and not self._COMMENT.match(line):
                para_lines.setdefault(current_para, []).append(line)

        # Score each paragraph
        for name, plines in para_lines.items():
            pc = ParagraphComplexity(name=name, line_count=len(plines))

            if_depth = 0
            max_depth = 0

            for line in plines:
                upper = line.upper()

                if self._GOTO.search(line):
                    pc.goto_count += 1

                if self._ALTER.search(line):
                    pc.alter_count += 1

                if self._PERFORM_THRU.search(line):
                    pc.perform_thru_count += 1

                if self._EVALUATE.search(line):
                    pc.evaluate_count += 1

                if self._CALL.search(line):
                    pc.call_count += 1

                if self._SORT_PROCEDURE.search(line):
                    pc.sort_procedure_count += 1

                if self._GOTO_DEPENDING.search(line):
                    pc.goto_depending_count += 1

                if self._INSPECT_TALLYING.search(line):
                    pc.inspect_tallying_count += 1

                # Track IF nesting depth
                if_matches = len(self._IF.findall(line))
                endif_matches = len(self._END_IF.findall(line))
                if_depth += if_matches - endif_matches
                # Period terminates all open IFs
                if line.strip().endswith('.') and 'IF' in upper:
                    if_depth = 0
                max_depth = max(max_depth, if_depth)

                # Count magic numbers (exclude PIC/VALUE clauses, loop
                # constructs, ACCEPT/DISPLAY date patterns, and string literals)
                stripped = line.strip()
                skip_magic = (
                    stripped.startswith('*>') or
                    'PIC' in upper or 'VALUE' in upper or
                    'FROM' in upper or 'BY' in upper or 'UNTIL' in upper or
                    'ACCEPT' in upper or
                    '"' in stripped or "'" in stripped
                )
                if not skip_magic:
                    pc.magic_number_count += len(self._MAGIC_NUM.findall(stripped))

            pc.max_if_depth = max_depth

            # Compute score
            pc.score = (
                pc.goto_count * 5 +
                pc.alter_count * 10 +
                pc.perform_thru_count * 3 +
                pc.max_if_depth * 1 +
                pc.evaluate_count * 1 +
                pc.magic_number_count * 1 +
                pc.call_count * 2 +
                pc.sort_procedure_count * 6 +
                pc.goto_depending_count * 7 +
                pc.inspect_tallying_count * 1
            )

            # Build factors list
            if pc.goto_count:
                pc.factors.append(f"GO TO x{pc.goto_count} (+{pc.goto_count * 5})")
            if pc.alter_count:
                pc.factors.append(f"ALTER x{pc.alter_count} (+{pc.alter_count * 10})")
            if pc.perform_thru_count:
                pc.factors.append(f"PERFORM THRU x{pc.perform_thru_count} (+{pc.perform_thru_count * 3})")
            if pc.max_if_depth > 1:
                pc.factors.append(f"Nested IF depth {pc.max_if_depth} (+{pc.max_if_depth})")
            if pc.call_count:
                pc.factors.append(f"CALL x{pc.call_count} (+{pc.call_count * 2})")
            if pc.sort_procedure_count:
                pc.factors.append(f"SORT PROCEDURE x{pc.sort_procedure_count} (+{pc.sort_procedure_count * 6})")
            if pc.goto_depending_count:
                pc.factors.append(f"GO TO DEPENDING ON x{pc.goto_depending_count} (+{pc.goto_depending_count * 7})")
            if pc.inspect_tallying_count:
                pc.factors.append(f"INSPECT TALLYING x{pc.inspect_tallying_count} (+{pc.inspect_tallying_count})")

            result.paragraphs[name] = pc

        # Add file-level COPY REPLACING score to total (not per-paragraph)
        copy_replacing_score = file_copy_replacing * 4

        result.total_score = sum(p.score for p in result.paragraphs.values()) + copy_replacing_score
        if result.total_score < 20:
            result.rating = "clean"
        elif result.total_score < 50:
            result.rating = "moderate"
        else:
            result.rating = "spaghetti"

        return result
