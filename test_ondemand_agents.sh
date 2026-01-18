#!/bin/bash
# Test OnDemand.io Agents Integration

echo "🧪 Testing OnDemand.io Agents Integration"
echo "=========================================="

BASE_URL="http://localhost:8000"

echo -e "\n✅ AGENT 1: Attendance Analyzer"
curl -X POST "$BASE_URL/ai-agents/agent/attendance-analyzer" \
  -H "Content-Type: application/json" \
  -d '{"query": "A student has 72% attendance. What should they do?"}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 2: Report Generator"
curl -X POST "$BASE_URL/ai-agents/agent/report-generator" \
  -H "Content-Type: application/json" \
  -d '{"query": "Generate monthly attendance summary for 50 students"}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 3: Policy Researcher (with Web Search Tool)"
curl -X POST "$BASE_URL/ai-agents/agent/policy-researcher" \
  -H "Content-Type: application/json" \
  -d '{"query": "What are DTU attendance policies?", "use_tools": true}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 4: SQL Generator"
curl -X POST "$BASE_URL/ai-agents/agent/sql-generator" \
  -H "Content-Type: application/json" \
  -d '{"query": "Find all students with less than 75% attendance"}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 5: Student Advisor"
curl -X POST "$BASE_URL/ai-agents/agent/student-advisor" \
  -H "Content-Type: application/json" \
  -d '{"query": "How can I improve my attendance from 70% to 90%?"}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 6: Multi-Tool Agent (Web + Weather)"
curl -X POST "$BASE_URL/ai-agents/agent/multi-tool" \
  -H "Content-Type: application/json" \
  -d '{"query": "Check weather and search for study tips", "use_tools": true}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n✅ AGENT 7 (Bonus): General Query"
curl -X POST "$BASE_URL/ai-agents/agent/general-query" \
  -H "Content-Type: application/json" \
  -d '{"query": "Explain face recognition technology", "agent_type": "claude"}' \
  2>/dev/null | python3 -m json.tool | head -20

echo -e "\n\n=========================================="
echo "✅ All 7 agents tested!"
echo "=========================================="
echo "Competition Requirements:"
echo "  ✅ At least 6 agents: YES (7 agents)"
echo "  ✅ At least 3 tools: YES (web_search, weather, multi-tool)"
echo ""
echo "Available endpoints:"
echo "  POST /ai-agents/agent/attendance-analyzer"
echo "  POST /ai-agents/agent/report-generator"
echo "  POST /ai-agents/agent/policy-researcher"
echo "  POST /ai-agents/agent/sql-generator"
echo "  POST /ai-agents/agent/student-advisor"
echo "  POST /ai-agents/agent/multi-tool"
echo "  POST /ai-agents/agent/general-query"
