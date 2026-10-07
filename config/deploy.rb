set :scm, :middleman

# The build keeps the unpacked unpoly-docs skill (build/skills/unpoly-docs/) for checks
# and local use, but unpoly.com only serves its archives and their indexes
# (Unpoly::Guide::SkillPackage). Patterns are matched against paths like
# build/skills/unpoly-docs/SKILL.md.
set :exclude_patterns, ['build/skills/**/*']
