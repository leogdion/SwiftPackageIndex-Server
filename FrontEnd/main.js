// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import '@hotwired/turbo'

import './scripts/dom_helpers.js'

import { ExternalLinkRetargeter } from './scripts/external_link_retargeter.js'
import { SPIWindowMonitor } from './scripts/window_monitor.js'
import { SPIPackageListNavigation } from './scripts/package_list_navigation.js'
import { SPICopyableInput } from './scripts/copy_buttons.js'
import { SPIBuildLogNavigation } from './scripts/build_log_navigation.js'
import { SPIAutofocus } from './scripts/autofocus.js'
import { SPIPlaygroundsAppLinkFallback } from './scripts/playgrounds_app_link.js'
import { SPIReadmeElement } from './scripts/readme_element.js'
import { SPITabBarElement } from './scripts/tab_bar_element.js'
import { SPIOverflowingList } from './scripts/overflowing_list.js'
import { SPISearchFilterSuggestions } from './scripts/search_filter_suggestions.js'
import { SPIPanel } from './scripts/panel.js'

new ExternalLinkRetargeter()
new SPIWindowMonitor()
new SPIPackageListNavigation()
new SPIBuildLogNavigation()
new SPICopyableInput()
new SPIAutofocus()
new SPIPlaygroundsAppLinkFallback()
new SPIShowMoreKeywords()
new SPISearchFilterSuggestions()
new SPIPanel()

customElements.define('spi-readme', SPIReadmeElement)
customElements.define('tab-bar', SPITabBarElement)

//# sourceMappingURL=main.js.map
