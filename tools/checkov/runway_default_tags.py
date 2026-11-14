"""Checkov custom check CKV_RUNWAY_1: every AWS provider block sets default_tags
with the keys project, lab and runway:ephemeral (value "true" or "false").

Why a checkov check and not a script or a tflint rule: checkov already runs in
CI and parses HCL properly, so this adds no dependency. A tflint rule would need
a compiled plugin; a regex script would miss aliased or multi-line blocks.
"""
from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.provider.base_check import BaseProviderCheck

REQUIRED = ("project", "lab", "runway:ephemeral")


def _first(value):
    while isinstance(value, list) and value:
        value = value[0]
    return value


class RunwayDefaultTags(BaseProviderCheck):
    def __init__(self):
        super().__init__(
            name="AWS provider sets default_tags project, lab and runway:ephemeral",
            id="CKV_RUNWAY_1",
            categories=[CheckCategories.GENERAL_SECURITY],
            supported_provider=["aws"],
        )

    def scan_provider_conf(self, conf):
        default_tags = _first(conf.get("default_tags"))
        if not isinstance(default_tags, dict):
            return CheckResult.FAILED
        tags = _first(default_tags.get("tags"))
        if not isinstance(tags, dict):
            return CheckResult.FAILED
        if any(key not in tags for key in REQUIRED):
            return CheckResult.FAILED
        if str(_first(tags["runway:ephemeral"])).lower() not in ("true", "false"):
            return CheckResult.FAILED
        return CheckResult.PASSED


check = RunwayDefaultTags()
