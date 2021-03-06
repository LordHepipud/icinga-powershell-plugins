# Upgrading Icinga PowerShell Plugins

Upgrading Icinga PowerShell Plugins is usually quite straightforward.

Specific version upgrades are described below. Please note that version updates are incremental.

## Upgrading to v1.1.0 (2020-06-02)

### Icinga PowerShell Framework dependency

To use the Icinga PowerShell Plugins v1.1.0 you will require to upgrade the Icinga PowerShell Framework to v1.1.0 first. This new plugin release will **not** work with older Framework versions.

### New Plugins

We have added two new plugins you can add into your Icinga 2 configuration by creating a basket configuration for the Icinga Director. The new plugins are

* [Invoke-IcingaCheckICMP](https://icinga.com/docs/windows/latest/plugins/doc/plugins/08-Invoke-IcingaCheckICMP/)
* [Invoke-IcingaCheckCertificate](https://icinga.com/docs/windows/latest/plugins/doc/plugins/02-Invoke-IcingaCheckCertificate/)
