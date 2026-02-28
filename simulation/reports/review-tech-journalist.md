# Dev Patel — Staff Writer, TechCrunch

**Covers developer tools, open-source highlights, and "GitHub repos you should know"**

## Rating: 3.8 / 5 stars

---

## First Impressions

Opening the repo, my editor brain immediately flags the hook: "COBOL isn't the problem. Lack of observability is." That's a thesis statement, not a project description. It tells me this developer has an opinion and built something to prove it. That's what makes a story.

The dark glass-morphism UI is unexpectedly polished for a COBOL project. The disconnect between "1959 programming language" and "2026 web console with frosted glass cards" is visually striking. That contrast is the angle.

---

## What Works

**The narrative is strong:**
- This isn't "I learned COBOL." It's "I built a 6-node banking settlement system to prove that legacy code can be observed, not replaced." That's a defensible position in the $3 trillion COBOL modernization industry.
- The teaching angle gives it legs beyond a portfolio piece — it could be used in actual CS courses.

**The demo is visual:**
- The network graph with 6 nodes and settlement flow is screenshot-worthy.
- The tamper → verify → detect flow is a 10-second GIF that would get engagement on Twitter/X.
- The spaghetti COBOL call graph (when it works) is genuinely interesting to look at.

**The numbers are compelling:**
- 14 COBOL programs, 547 tests, 42 accounts across 6 nodes, 47 API endpoints
- These are real numbers, not inflated. The test count alone puts this ahead of 99% of portfolio projects.

**The scope is ambitious but complete:**
- COBOL banking system + Python integrity layer + REST API + Web console + LLM chat + Static analysis
- Each layer works (mostly) and connects to the others. This isn't vaporware.

---

## What's Missing / Could Improve

**README needs hero screenshots:**
- I see `docs/screenshots/` referenced but I need to clone and run the app to see it. For a "repos you should know" article, I need screenshots *in the README itself*. The dashboard with the network graph, the tamper detection moment, the call graph — these should be embedded images, not file paths.

**No live demo:**
- A GitHub Pages site or a 30-second video would 10x the reach. Most readers won't clone a repo with COBOL dependencies.
- Even a GIF of the simulation running would work for social media.

**The broken features hurt the story:**
- If I'm demoing this for an article and the chat tab shows a JSON error, or the analysis tab 404s on the spaghetti files, that undermines the "feature-complete" claim. I can't write "fully functional" if features are broken.

**The COBOL angle needs positioning:**
- "Learn COBOL" competes with IBM's free courseware, Microfocus tutorials, and university curricula.
- "See why COBOL systems are hard to observe and what to do about it" — that's the unique angle. The README should lead with the observability thesis, not the COBOL teaching.

**Social proof is absent:**
- No stars, no forks, no community discussion. For an article, I'd want to see some traction — even 10 stars shows someone else found it useful.
- No blog post or dev.to article explaining the project. A companion writeup ("I Built a COBOL Banking System to Teach Modern Developers About Legacy Code") would be highly shareable.

---

## WOW Moments

1. **The spaghetti payroll sidecar with fictional developer history.** JRK's 1974 GO TO spaghetti, PMR's 1983 nested IFs, the Y2K team's dead code — this is *storytelling through code*. I've never seen a GitHub repo that creates fictional developer personas to teach anti-patterns. That's creative and memorable.

2. **The compliance detection.** A simulated banking system that detects structuring patterns and CTR threshold violations? That's crossing from "teaching tool" into "domain simulation." Financial regulators would find this interesting.

3. **The "wrap, don't modify" philosophy made tangible.** Every tech publication has written about COBOL modernization abstractly. This project makes the argument concrete — here's legacy code, here's the observation wrapper, here's what you can see now that you couldn't before.

---

## Deal Breakers (for article inclusion)

**No embedded screenshots in README** — I can't feature a repo I can't screenshot without cloning.

**Broken demo paths** — The chat and analysis features need to work end-to-end for me to call it "feature-complete."

**No companion content** — A blog post, video, or Twitter thread explaining the project would make it 5x more linkable.

---

## Verdict

**Would I write a "GitHub Repos You Should Know" article featuring this?** Not yet, but close.

**What would get it over the line:**
1. Fix the broken features (chat, analysis payroll loading)
2. Embed 3-4 screenshots in the README (dashboard, tamper detection, call graph, chat with tool-use)
3. Write a companion blog post: "I Built a COBOL Banking System to Prove Legacy Code Isn't the Problem"
4. Create a 30-second GIF or video of the simulation running
5. Share it on Hacker News or r/programming and get initial community feedback

**The angle I'd use:** "While banks spend billions replacing COBOL, one developer built a system proving the real problem isn't the code — it's the observability. And they did it with SHA-256 hash chains, a web console, and an LLM that can query accounts."

**Headline draft:** "This Open-Source COBOL Banking System Might Change How You Think About Legacy Code"

The project has the substance. It just needs the packaging.
