"""
Tests for python.cobol_analyzer.knowledge_base -- COBOL pattern encyclopedia.

Verifies lookup, partial matching, search, category filtering, and entry
field completeness for all ~20 knowledge base entries.
"""

import pytest
from python.cobol_analyzer.knowledge_base import KnowledgeBase, ENTRIES


class TestKnowledgeBaseLookup:
    def setup_method(self):
        self.kb = KnowledgeBase()

    def test_lookup_exact_alter(self):
        entry = self.kb.lookup("ALTER")
        assert entry is not None
        assert entry["name"] == "ALTER"

    def test_lookup_exact_goto(self):
        entry = self.kb.lookup("GO TO")
        assert entry is not None
        assert entry["name"] == "GO TO"

    def test_lookup_perform_thru(self):
        entry = self.kb.lookup("PERFORM THRU")
        assert entry is not None

    def test_lookup_comp3(self):
        entry = self.kb.lookup("COMP-3")
        assert entry is not None

    def test_lookup_redefines(self):
        entry = self.kb.lookup("REDEFINES")
        assert entry is not None

    def test_lookup_case_insensitive(self):
        entry = self.kb.lookup("alter")
        assert entry is not None
        assert entry["name"] == "ALTER"

    def test_lookup_partial_match(self):
        """Partial match should find entries containing the search term."""
        entry = self.kb.lookup("88-level")
        assert entry is not None

    def test_lookup_unknown_returns_none(self):
        entry = self.kb.lookup("NONEXISTENT-PATTERN-XYZ-999")
        assert entry is None


class TestKnowledgeBaseEntryFields:
    """Every entry must have all required fields populated."""

    REQUIRED_FIELDS = [
        "name", "category", "era", "purpose",
        "mainframe_context", "modern_equivalent", "example", "risk",
    ]

    def test_all_entries_have_required_fields(self):
        kb = KnowledgeBase()
        for name in ENTRIES:
            entry = kb.lookup(name)
            assert entry is not None, f"Failed to lookup entry: {name}"
            for field in self.REQUIRED_FIELDS:
                assert field in entry, f"Entry '{name}' missing field: {field}"
                assert entry[field], f"Entry '{name}' has empty field: {field}"

    def test_entry_count(self):
        """Knowledge base should have at least 18 entries."""
        assert len(ENTRIES) >= 18

    def test_categories_are_valid(self):
        valid = {"control_flow", "data", "file_io", "mainframe", "anti_pattern"}
        for name, entry in ENTRIES.items():
            assert entry.category in valid, (
                f"Entry '{name}' has invalid category: {entry.category}"
            )


class TestKnowledgeBaseSearch:
    def setup_method(self):
        self.kb = KnowledgeBase()

    def test_search_returns_results(self):
        results = self.kb.search("GO TO")
        assert len(results) >= 1

    def test_search_case_insensitive(self):
        results = self.kb.search("cobol-68")
        assert len(results) >= 1

    def test_search_broad_term(self):
        """Searching for 'mainframe' should match several entries."""
        results = self.kb.search("mainframe")
        assert len(results) >= 3

    def test_search_empty_returns_all(self):
        """Empty query matches all entries."""
        results = self.kb.search("")
        assert len(results) >= 18


class TestKnowledgeBaseListPatterns:
    def setup_method(self):
        self.kb = KnowledgeBase()

    def test_list_all(self):
        results = self.kb.list_patterns()
        assert len(results) >= 18

    def test_list_by_category(self):
        results = self.kb.list_patterns(category="control_flow")
        assert len(results) >= 3
        assert all(r["category"] == "control_flow" for r in results)

    def test_list_anti_patterns(self):
        results = self.kb.list_patterns(category="anti_pattern")
        assert len(results) >= 4

    def test_list_entries_have_summary_fields(self):
        results = self.kb.list_patterns()
        for r in results:
            assert "name" in r
            assert "category" in r
            assert "era" in r
            assert "purpose" in r
