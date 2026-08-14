resource "netbox_config_template" "ios_ntp" {
  name          = "ios-ntp"
  template_code = "{% for ntp in ntp_servers %}\nntp server {{ ntp }}\n{% endfor %}"
}
