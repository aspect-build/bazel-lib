# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"Helpers for rules running on windows"

load(
    "//lib/private:windows_utils.bzl",
    _IS_EXEC_PLATFORM_WINDOWS_ATTRS = "IS_EXEC_PLATFORM_WINDOWS_ATTRS",
    _create_windows_native_launcher_script = "create_windows_native_launcher_script",
    _is_exec_platform_windows = "is_exec_platform_windows",
)

IS_EXEC_PLATFORM_WINDOWS_ATTRS = _IS_EXEC_PLATFORM_WINDOWS_ATTRS
is_exec_platform_windows = _is_exec_platform_windows
create_windows_native_launcher_script = _create_windows_native_launcher_script
