import Migration from 'contentful-migration-cli'

export = function (migration: Migration) {
  const page = migration.createContentType('page')
    .name('Page')
    .description('A page describes a collection of sections that correspond' +
     'to a URL slug')
    .displayField('title')

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

}
