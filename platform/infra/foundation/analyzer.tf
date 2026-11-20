# Flags any resource in the organization shared with a principal outside it. External access
# findings are free; unused-access analysis is paid and stays off.
resource "aws_accessanalyzer_analyzer" "org" {
  analyzer_name = "runway-org-external-access"
  type          = "ORGANIZATION"
  depends_on    = [aws_organizations_organization.this]
}
