# Nomad Enterprise HVD - client example

This example deploys Nomad clients to join an existing Nomad cluster. The clients can join via a specified tag with setting `auto_join_tag`.

Runtimes are not enabled by default. To enable a runtime, modify the `install_runtime` function in the `templates\nomad_custom_data.sh.tpl` with the code to enable any runtimes as needed.
