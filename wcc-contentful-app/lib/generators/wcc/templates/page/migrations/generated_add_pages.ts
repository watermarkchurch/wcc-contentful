import Migration from '@watermarkchurch/contentful-migration'

export = function (migration: Migration) {
  const page = migration.createContentType('page')
    .name('Page')
    .description('A page describes a collection of sections that correspond' +
     'to a URL slug')
    .displayField('internalTitle')

  page.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true,
  })

  page.createField('title')
    .name('Title')
    .type('Symbol')
    .required(true)

  page.createField('slug')
    .name('Slug')
    .type('Symbol')
    .required(true)
    .validations([
      {
        unique: true
      },
      {
        regexp: { pattern: "(\\/|\\/([\w#!:.?+=&%@!\\-\\/]))?$" },
        message: "The slug must look like the path part of a URL and begin with a forward slash, example: '/my-page-slug'"
      }
    ])

  page.createField('sections')
    .name('Sections')
    .type('Array')
    .items({
      type: 'Link',
      linkType: 'Entry'
    })

  page.createField('subpages')
    .name('Subpages')
    .type('Array')
    .items({
      type: 'Link',
      linkType: 'Entry',
      validations: [
        {
          linkContentType: [ 'page' ]
        }
      ]
    })

  /************  redirect  ******************/

  var redirect = migration.createContentType('redirect', {
    displayField: 'internalTitle',
    name: 'Redirect',
    description: ''
  })

  redirect.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true,
  })

  redirect.createField('slug', {
    name: 'Slug',
    type: 'Symbol',
    localized: false,
    required: true,
    validations:
      [{ unique: true },
      {
        regexp:
        {
          pattern: '\\/(?:[\\w#!:.?+=&%@!\\-]\\/?)*$',
          flags: null
        },
        message: 'The slug must look like the path part of a URL and begin with a forward slash, example: \'/my-page-slug\''
      }],
    disabled: false,
    omitted: false
  })

  redirect.createField('externalLink', {
    name: 'External Link',
    type: 'Symbol',
    localized: false,
    required: false,
    validations:
      [{
        regexp:
        {
          pattern: '^([^\\s\\:]+):(\\/\\/)?(\\w+:{0,1}\\w*@)?(([^\\s\\/#]+\\.)+[^\\s\\/#]+)(:[0-9]+)?(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))?$|^(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))$',
          flags: null
        },
        message: 'The external link must be a URL like \'https://www.watermark.org/\', a mailto url like \'mailto:info@watermark.org\', or a relative URL like \'#location-on-page\''
      }],
    disabled: false,
    omitted: false
  })

  redirect.createField('pageLink', {
    name: 'Page Link',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkContentType: ['page'] }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  redirect.createField('sectionLink', {
    name: 'Section Link',
    type: 'Link',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  redirect.changeEditorInterface('internalTitle', 'singleLine')

  redirect.changeEditorInterface('slug', 'slugEditor')

  redirect.changeEditorInterface('externalLink', 'urlEditor', { helpText: 'An external URL to send people to, that is not a page on this site.  Use this OR Page Link, you can\'t use both.' })

  redirect.changeEditorInterface('pageLink', 'entryCardEditor', { helpText: 'A page on this site to send people to.  Use this OR External Link, you can\'t use both.' })

  redirect.changeEditorInterface('sectionLink', 'entryLinkEditor', { helpText: '(Optional) If provided, this will link the user to the specific section on a page.  If you use this, you must also use Page Link.' })

}
