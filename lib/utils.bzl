"Public API"

load("//lib/private:utils.bzl", "utils")

is_external_label = utils.is_external_label
glob_directories = utils.glob_directories
path_to_root = utils.path_to_root
propagate_well_known_tags = utils.propagate_well_known_tags
is_darwin = utils.is_darwin
to_label = utils.to_label
