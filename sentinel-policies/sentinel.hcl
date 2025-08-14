policy "check-required-tags" {
  source            = "./check-tags.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "check-instance-types" {
  source            = "./check-instance-types.sentinel"
  enforcement_level = "soft-mandatory"
}

policy "check-cost-limits" {
  source            = "./check-costs.sentinel"
  enforcement_level = "advisory"
}