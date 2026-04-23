#!/usr/bin/env ruby
require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'KeyTok.xcodeproj')

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastUpgradeCheck'] = '1640'

main_group = project.main_group
app_group = main_group.new_group('App', 'App')
app_direct_group = app_group.new_group('Direct', 'Direct')
app_store_group = app_group.new_group('AppStore', 'AppStore')

core_group = main_group.new_group('Core', 'Core')
core_app_group = core_group.new_group('App', 'App')
core_audio_group = core_group.new_group('Audio', 'Audio')
core_input_group = core_group.new_group('Input', 'Input')
core_models_group = core_group.new_group('Models', 'Models')
core_support_group = core_group.new_group('Support', 'Support')
core_ui_group = core_group.new_group('UI', 'UI')

tests_group = main_group.new_group('Tests', 'Tests')
tests_core_group = tests_group.new_group('KeyTokCoreTests', 'KeyTokCoreTests')
config_group = main_group.new_group('Config', 'Config')
scripts_group = main_group.new_group('script', 'script')
docs_group = main_group.new_group('docs', 'docs')
github_group = main_group.new_group('.github', '.github')
github_workflows_group = github_group.new_group('workflows', 'workflows')
homebrew_group = main_group.new_group('Homebrew', 'Homebrew')
homebrew_casks_group = homebrew_group.new_group('Casks', 'Casks')

file_refs = {}

{
  app_direct_group => %w[
    DirectAppDelegate.swift
    KeyTokDirectApp.swift
  ],
  app_store_group => %w[
    AppStoreAppDelegate.swift
    KeyTokAppStoreApp.swift
  ],
  core_app_group => %w[
    KeyTokCoordinator.swift
    SettingsWindowController.swift
  ],
  core_audio_group => %w[
    AudioPlaybackEngine.swift
    SoundPack.swift
    SoundPackLibrary.swift
    SoundSynthesis.swift
  ],
  core_input_group => %w[
    EventTapKeyboardEventSource.swift
    KeyClassifier.swift
    KeyboardEventSource.swift
    KeyboardEventSourceFactory.swift
    MonitorKeyboardEventSource.swift
  ],
  core_models_group => %w[
    AppChannel.swift
    KeyClass.swift
    KeyEvent.swift
  ],
  core_support_group => %w[
    KeyboardPermissionManager.swift
    KeyboardPermissionStatus.swift
    KeyTokLogger.swift
    LaunchAtLoginManager.swift
  ],
  core_ui_group => %w[
    MenuBarContentView.swift
    MenuBarLabelView.swift
    SettingsWindowView.swift
  ],
  tests_core_group => %w[
    KeyClassifierTests.swift
    SoundPackLibraryTests.swift
  ],
  config_group => %w[
    KeyTokAppStore-Info.plist
    KeyTokAppStore.entitlements
    KeyTokDirect-Info.plist
  ],
  scripts_group => %w[
    build_and_run.sh
    generate_xcodeproj.rb
    package_direct_release.sh
    render_homebrew_cask.rb
  ],
  docs_group => %w[
    app-store-validation.md
    release.md
  ],
  github_workflows_group => %w[
    ci.yml
    direct-release.yml
  ],
  homebrew_casks_group => %w[
    keytok.rb.erb
  ]
}.each do |group, paths|
  paths.each do |path|
    file_refs[path] = group.new_file(path)
  end
end

direct_target = project.new_target(:application, 'KeyTokDirect', :osx, '14.0', nil, :swift)
app_store_target = project.new_target(:application, 'KeyTokAppStore', :osx, '14.0', nil, :swift)
core_target = project.new_target(:framework, 'KeyTokCore', :osx, '14.0', nil, :swift)
test_target = project.new_target(:unit_test_bundle, 'KeyTokCoreTests', :osx, '14.0', nil, :swift)

core_source_files = %w[
  App/KeyTokCoordinator.swift
  App/SettingsWindowController.swift
  Audio/AudioPlaybackEngine.swift
  Audio/SoundPack.swift
  Audio/SoundPackLibrary.swift
  Audio/SoundSynthesis.swift
  Input/EventTapKeyboardEventSource.swift
  Input/KeyClassifier.swift
  Input/KeyboardEventSource.swift
  Input/KeyboardEventSourceFactory.swift
  Input/MonitorKeyboardEventSource.swift
  Models/AppChannel.swift
  Models/KeyClass.swift
  Models/KeyEvent.swift
  Support/KeyboardPermissionManager.swift
  Support/KeyboardPermissionStatus.swift
  Support/KeyTokLogger.swift
  Support/LaunchAtLoginManager.swift
  UI/MenuBarContentView.swift
  UI/MenuBarLabelView.swift
  UI/SettingsWindowView.swift
]

direct_source_files = %w[
  Direct/DirectAppDelegate.swift
  Direct/KeyTokDirectApp.swift
]

app_store_source_files = %w[
  AppStore/AppStoreAppDelegate.swift
  AppStore/KeyTokAppStoreApp.swift
]

test_source_files = %w[
  KeyTokCoreTests/KeyClassifierTests.swift
  KeyTokCoreTests/SoundPackLibraryTests.swift
]

core_target.add_file_references(core_source_files.map { |path| file_refs[File.basename(path)] })
direct_target.add_file_references(direct_source_files.map { |path| file_refs[File.basename(path)] })
app_store_target.add_file_references(app_store_source_files.map { |path| file_refs[File.basename(path)] })
test_target.add_file_references(test_source_files.map { |path| file_refs[File.basename(path)] })

[direct_target, app_store_target, test_target].each do |target|
  target.add_dependency(core_target)
  target.frameworks_build_phase.add_file_reference(core_target.product_reference, true)
end

[direct_target, app_store_target].each do |target|
  embed_phase = target.copy_files_build_phases.find { |phase| phase.display_name == 'Embed Frameworks' } || target.new_copy_files_build_phase('Embed Frameworks')
  embed_phase.dst_subfolder_spec = '10'
  build_file = embed_phase.add_file_reference(core_target.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }
end

common_target_settings = {
  'MACOSX_DEPLOYMENT_TARGET' => '14.0',
  'SWIFT_VERSION' => '5.0',
  'MARKETING_VERSION' => '0.1.0',
  'CURRENT_PROJECT_VERSION' => '1',
  'CLANG_ENABLE_MODULES' => 'YES',
  'ENABLE_HARDENED_RUNTIME' => 'YES',
  'SWIFT_STRICT_CONCURRENCY' => 'minimal'
}

project.build_configurations.each do |configuration|
  configuration.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
end

core_target.build_configurations.each do |configuration|
  configuration.build_settings.merge!(common_target_settings)
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.keytok.core'
  configuration.build_settings['DEFINES_MODULE'] = 'YES'
  configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  configuration.build_settings['SKIP_INSTALL'] = 'YES'
  configuration.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks', '@loader_path/../Frameworks']

  if configuration.name == 'Debug'
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  end
end

direct_target.build_configurations.each do |configuration|
  configuration.build_settings.merge!(common_target_settings)
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.keytok.direct'
  configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  configuration.build_settings['INFOPLIST_FILE'] = 'Config/KeyTokDirect-Info.plist'
  configuration.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  configuration.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  configuration.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'

  if configuration.name == 'Debug'
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  end
end

app_store_target.build_configurations.each do |configuration|
  configuration.build_settings.merge!(common_target_settings)
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.keytok.appstore'
  configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  configuration.build_settings['INFOPLIST_FILE'] = 'Config/KeyTokAppStore-Info.plist'
  configuration.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Config/KeyTokAppStore.entitlements'
  configuration.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks']
  configuration.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  configuration.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'

  if configuration.name == 'Debug'
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  end
end

test_target.build_configurations.each do |configuration|
  configuration.build_settings.merge!(common_target_settings)
  configuration.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.keytok.coretests'
  configuration.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  configuration.build_settings['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@loader_path/../Frameworks', '@executable_path/../Frameworks']
  configuration.build_settings['TEST_HOST'] = ''
  configuration.build_settings['BUNDLE_LOADER'] = ''

  if configuration.name == 'Debug'
    configuration.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    configuration.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
  end
end

def save_scheme(project_path, scheme_name, build_targets:, launch_target: nil, test_target: nil)
  scheme = Xcodeproj::XCScheme.new
  build_targets.each do |target|
    scheme.add_build_target(target)
  end

  if test_target
    scheme.add_test_target(test_target)
    scheme.test_action.code_coverage_enabled = true
  end

  scheme.set_launch_target(launch_target) if launch_target
  scheme.profile_action.build_configuration = 'Release'
  scheme.archive_action.build_configuration = 'Release'
  scheme.save_as(project_path, scheme_name, true)
end

save_scheme(
  project.path,
  'KeyTokDirect',
  build_targets: [core_target, direct_target],
  launch_target: direct_target,
  test_target: test_target
)

save_scheme(
  project.path,
  'KeyTokAppStore',
  build_targets: [core_target, app_store_target],
  launch_target: app_store_target
)

project.save
