# Disable the strict Solr checksum verification check
AppConfig[:solr_verify_checksums] = false

# Plugin hot-reloading
AppConfig[:development_mode] = true
AppConfig[:changed_models_reload_frequency] = 0
AppConfig[:reload_templates] = true

# Register your custom development plugin
AppConfig[:plugins] = ['hello_world']

# compile assets dynamically on the fly in dev.
AppConfig[:assets_compile] = true