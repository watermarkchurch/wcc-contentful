import Migration, { MigrationFunction } from '@watermarkchurch/contentful-migration'

export = function(migration: Migration, { makeRequest, spaceId, accessToken }) {

  const sectionCodeWidget = migration.createContentType('section-code-widget', {
    displayField:
      'internalTitle',
    name:
      'Section: Code Widget',
    description:
      'Render code defined section views from JSON parameters.',
  })

  sectionCodeWidget.createField('internalTitle', {
    name:
      'Internal Title',
    type:
      'Symbol',
    localized:
      false,
    required:
      true,
    validations:
      [],
    disabled:
      false,
    omitted:
      true,
  })

  sectionCodeWidget.createField('view', {
    name:
      'View',
    type:
      'Symbol',
    localized:
      false,
    required:
      true,
    validations:
      [],
    disabled:
      false,
    omitted:
      false,
  })

  sectionCodeWidget.createField('parameters', {
    name:
      'Parameters',
    type:
      'Object',
    localized:
      false,
    required:
      false,
    validations:
      [],
    disabled:
      false,
    omitted:
      false,
  })

  sectionCodeWidget.createField('bookmarkTitle', {
    name:
      'Bookmark Title',
    type:
      'Symbol',
    localized:
      false,
    required:
      false,
    validations:
      [],
    disabled:
      false,
    omitted:
      false,
  })

  sectionCodeWidget.changeEditorInterface('internalTitle', 'singleLine')

  sectionCodeWidget.changeEditorInterface('view', 'dropdown')

  sectionCodeWidget.changeEditorInterface('parameters', 'objectEditor', { helpText: 'These parameters may or may not be required by the code widget.  Inspect the ruby code to see what to put here.' })

  sectionCodeWidget.changeEditorInterface('bookmarkTitle', 'singleLine')

} as MigrationFunction
