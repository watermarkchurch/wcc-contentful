import Migration, { MigrationFunction } from '@watermarkchurch/contentful-migration'

// Generated by contentful-schema-diff
// from empty-export.json
// to   7yx6ovlj39n5
export = function(migration : Migration, { makeRequest, spaceId, accessToken }) {

  /************  site-config  ******************/

  var siteConfig = migration.createContentType('site-config', {
    displayField: 'title',
    name: 'Site Config',
    description: 'This is the top level object for the configuration of your site.'
  })

  siteConfig.createField('title', {
    name: 'Title',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [{ unique: true }],
    disabled: false,
    omitted: false
  })

  siteConfig.createField('foreignKey', {
    name: 'Foreign Key',
    type: 'Symbol',
    localized: false,
    required: true,
    validations:
      [{ unique: true },
      {
        in: ['default'],
        message: 'We only allow the default site config for this site'
      }],
    disabled: false,
    omitted: false
  })

  siteConfig.createField('homepage', {
    name: 'Homepage',
    type: 'Link',
    localized: false,
    required: true,
    validations: [{ linkContentType: ['page'] }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  siteConfig.createField('mainNavigation', {
    name: 'Main Navigation',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkContentType: ['menu'] }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  siteConfig.createField('brand', {
    name: 'Brand',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkContentType: ['menuButton'] }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  siteConfig.createField('emailHeader', {
    name: 'Email Header',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkMimetypeGroup: ['image'] }],
    disabled: false,
    omitted: false,
    linkType: 'Asset'
  })

  siteConfig.changeEditorInterface('title', 'singleLine')

  siteConfig.changeEditorInterface('foreignKey', 'radio', { helpText: 'Must be `default`' })

  siteConfig.changeEditorInterface('homepage', 'entryLinkEditor')

  siteConfig.changeEditorInterface('mainNavigation', 'entryLinkEditor')

  siteConfig.changeEditorInterface('brand', 'entryLinkEditor')

  siteConfig.changeEditorInterface('emailHeader', 'assetLinkEditor')

} as MigrationFunction