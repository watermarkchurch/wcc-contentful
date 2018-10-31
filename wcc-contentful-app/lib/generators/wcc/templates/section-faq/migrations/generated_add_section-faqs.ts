import Migration, { MigrationFunction } from '@watermarkchurch/contentful-migration'

// Generated by contentful-schema-diff
// from empty-export.json
// to   4gyidsb2jx1u
export = function(migration : Migration, { makeRequest, spaceId, accessToken }) {

  /************  faq  ******************/

  var faq = migration.createContentType('faq', {
    displayField: 'questions',
    name: 'FAQ',
    description: ''
  })

  faq.createField('questions', {
    name: 'Questions',
    type: 'Text',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  faq.createField('answers', {
    name: 'Answers',
    type: 'Text',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  faq.changeEditorInterface('questions', 'multipleLine')

  faq.changeEditorInterface('answers', 'markdown')

  /************  section-faq  ******************/

  var sectionFaq = migration.createContentType('section-faq', {
    displayField: 'internalTitle',
    name: 'Section: FAQ',
    description: '(v2) A section containing a number of expandable frequently asked questions'
  })

  sectionFaq.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true
  })

  sectionFaq.createField('title', {
    name: 'Title',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  sectionFaq.createField('bookmarkTitle', {
    name: 'Bookmark Title',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  sectionFaq.createField('numberOfFaqsBeforeFold', {
    name: 'Number of Faqs Before Fold',
    type: 'Integer',
    localized: false,
    required: false,
    validations: [{ range: { min: 1, max: Infinity } }],
    disabled: false,
    omitted: false
  })

  sectionFaq.createField('faqs', {
    name: 'FAQs',
    type: 'Array',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: false,
    items:
    {
      type: 'Link',
      validations: [{ linkContentType: ['faq'] }],
      linkType: 'Entry'
    }
  })

  sectionFaq.createField('foldButtonShowText', {
    name: 'Fold Button Show More Text',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  sectionFaq.createField('foldButtonHideText', {
    name: 'Fold Button Show Less Text',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  sectionFaq.changeEditorInterface('internalTitle', 'singleLine')

  sectionFaq.changeEditorInterface('title', 'singleLine')

  sectionFaq.changeEditorInterface('bookmarkTitle', 'singleLine')

  sectionFaq.changeEditorInterface('numberOfFaqsBeforeFold', 'numberEditor')

  sectionFaq.changeEditorInterface('faqs', 'entryLinksEditor')

  sectionFaq.changeEditorInterface('foldButtonShowText', 'singleLine')

  sectionFaq.changeEditorInterface('foldButtonHideText', 'singleLine')

} as MigrationFunction
