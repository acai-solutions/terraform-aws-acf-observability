output "cf_template_map" {
  value = {
    "observability_member.yaml.tftpl"  = data.template_file.oam_member.rendered
    "observability_sink.yaml.tftpl" = data.template_file.oam_sink.rendered
  }
}
