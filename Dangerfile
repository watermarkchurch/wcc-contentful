# frozen_string_literal: true

# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? '#trivial'
wip = github.pr_title.include? '[WIP]'
demo = github.pr_title.include? '[DEMO]'
all_files = (git.added_files + git.modified_files + git.deleted_files + git.renamed_files)

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
message('PR is classed as Work in Progress', sticky: false) if wip
message('PR is classed as Demo', sticky: false) if demo

# Warn when there is a big PR
warn('This is a big pull request - please break it up into smaller units of work') if git.lines_of_code > 1000

return if wip || demo

unless declared_trivial
  unless github.pr_body =~ /(fix(es)?|close(s)?|ref(s)?)\s+\#\d+/i
    warn('No issue referenced - please create an issue describing a single unit of work and reference it using "closes #[the issue number]"', sticky: false)
  end
end

# Run all checks in WM plugin
wcc.all(reek: false)
