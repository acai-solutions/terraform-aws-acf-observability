data "template_file" "oam_member" {
  template = file("${path.module}/oam_member.yaml.tftpl")
  vars = {}
}

data "template_file" "oam_sink" {
  template = file("${path.module}/oam_sink.yaml.tftpl")
  vars = {}
}

