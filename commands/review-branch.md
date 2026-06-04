Review the current branch against main.

1. Run `git diff main...HEAD` to get all changes since branching from main
2. Create the output directory if missing: `mkdir -p .reviews`
3. Write the full review to `.reviews/$(date +%Y-%m-%dT%H-%M-%S).md`

Structure the review with one section per changed file:

---
## <filename>

For each file cover:
- Code quality and best practices
- Potential bugs or logic errors
- Security concerns (OWASP Top 10: injection, XSS, broken auth, sensitive data exposure, CSRF, SSRF, etc.)
- Test coverage gaps
- Performance considerations

Rate each finding: **CRITICAL** / **HIGH** / **MEDIUM** / **LOW**

---

Use `path/to/file.go:linenumber` references for specific issues so they can be navigated directly in the editor.
If there are no findings for a file, a one-line "No issues found." is enough.
