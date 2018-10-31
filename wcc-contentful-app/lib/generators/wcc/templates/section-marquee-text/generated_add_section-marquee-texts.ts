import Migration, { MigrationFunction } from '@watermarkchurch/contentful-migration'

// Generated by contentful-schema-diff
// from empty-export.json
// to   7yx6ovlj39n5
export = function(migration : Migration, { makeRequest, spaceId, accessToken }) {

  /************  section-marquee-text  ******************/

  var sectionMarqueeText = migration.createContentType('section-marquee-text', {
    displayField: 'internalTitle',
    name: 'Section: Marquee Text',
    description: 'Display a large section title and an enlarged single paragraph along with an optional tagline at the top.'
  })

  sectionMarqueeText.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true
  })

  sectionMarqueeText.createField('tag', {
    name: 'Tag',
    type: 'Symbol',
    localized: true,
    required: false,
    validations: [{ size: { min: 0, max: 50 } }],
    disabled: false,
    omitted: false
  })

  sectionMarqueeText.createField('title', {
    name: 'Title',
    type: 'Symbol',
    localized: true,
    required: true,
    validations: [{ size: { min: 0, max: 150 } }],
    disabled: false,
    omitted: false
  })

  sectionMarqueeText.createField('body', {
    name: 'Body',
    type: 'Text',
    localized: true,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  sectionMarqueeText.changeEditorInterface('tag', 'singleLine')

  sectionMarqueeText.changeEditorInterface('title', 'singleLine')

  sectionMarqueeText.changeEditorInterface('body', 'multipleLine')

  sectionMarqueeText.changeEditorInterface('internalTitle', 'singleLine')

} as MigrationFunction
