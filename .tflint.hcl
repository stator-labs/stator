# Bundled terraform ruleset only. The AWS ruleset is a separate plugin download;
# checkov covers AWS misconfigurations, so it is not worth the extra dependency.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
