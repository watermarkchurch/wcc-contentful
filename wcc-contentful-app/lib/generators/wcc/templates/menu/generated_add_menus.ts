
import Migration from 'contentful-migration-cli'

export = function (migration: Migration) {
  const menu = migration.createContentType('menu', {
    displayField: 'name',
    name: 'Menu',
    description: 'A Menu contains a number of Menu Buttons or other Menus, ' +
      'which will be rendered as drop-downs.'
  })

  menu.createField('name', {
    name: 'Menu Name',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: false
  })

  menu.createField('items', {
    name: 'Items',
    type: 'Array',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    items:
      {
        type: 'Link',
        validations:
          [{
            linkContentType:
              ['dropdownMenu',
                'menuButton'],
            message: 'The items must be either buttons or drop-down menus.'
          }],
        linkType: 'Entry'
      }
  })

  menu.changeEditorInterface('name', 'singleLine')
  menu.changeEditorInterface('items', 'entryLinksEditor')

  const menubutton = migration.createContentType('menuButton', {
    displayField: 'text',
    name: 'Menu Button',
    description: 'A Menu Button is a clickable button that goes on a Menu.  It has a link to a Page or a URL.'
  })

  menubutton.createField('text', {
    name: 'Text',
    type: 'Symbol',
    localized: false,
    required: true,
    validations:
      [{
        size:
          {
            min: 1,
            max: 60
          },
        message: 'A Menu Button should have a very short text field - ideally a single word.  Please limit the text to 60 characters.'
      }],
    disabled: false,
    omitted: false
  })

  menubutton.createField('icon', {
    name: 'Icon',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkMimetypeGroup: ['image'] }],
    disabled: false,
    omitted: false,
    linkType: 'Asset'
  })

  menubutton.createField('externalLink', {
    name: 'External Link',
    type: 'Symbol',
    localized: false,
    required: false,
    validations:
      [{
        regexp: { pattern: '^(\\w+):(\\/\\/)?(\\w+:{0,1}\\w*@)?((\\w+\\.)+[^\\s\\/#]+)(:[0-9]+)?(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))?$|^(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))$' },
        message: 'The external link must be a URL like \'https://www.watermark.org/\', a mailto url like \'mailto:info@watermark.org\', or a relative URL like \'#location-on-page\''
      }],
    disabled: false,
    omitted: false
  })

  menubutton.createField('link', {
    name: 'Page Link',
    type: 'Link',
    localized: false,
    required: false,
    validations:
      [{
        linkContentType: ['page'],
        message: 'The Page Link must be a link to a Page which has a slug.'
      }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  menubutton.createField('ionIcon', {
    name: 'Ion Icon',
    type: 'Symbol',
    localized: false,
    required: false,
    validations:
      [{
        regexp: { pattern: '^ion-[a-z\\-]+$' },
        message: 'The icon should start with \'ion-\', like \'ion-arrow-down-c\'.  See http://ionicons.com/'
      }],
    disabled: false,
    omitted: false
  })

  menubutton.createField('style', {
    name: 'Style',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [{ in: ['oval-border'] }],
    disabled: false,
    omitted: false
  })

  menubutton.changeEditorInterface('text', 'singleLine')
  menubutton.changeEditorInterface('icon', 'assetLinkEditor')
  menubutton.changeEditorInterface('externalLink', 'singleLine')
  menubutton.changeEditorInterface('link', 'entryLinkEditor')
  menubutton.changeEditorInterface('ionIcon', 'singleLine')
  menubutton.changeEditorInterface('style', 'dropdown')

  const dropdownmenu = migration.createContentType('dropdownMenu', {
    displayField: 'name',
    name: 'Dropdown Menu',
    description: 'A Dropdown Menu can be attached to a main menu to show additional menu items on click.'
  })

  dropdownmenu.createField('name', {
    name: 'Menu Name',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  })

  dropdownmenu.createField('label', {
    name: 'Menu Label',
    type: 'Link',
    localized: false,
    required: false,
    validations: [{ linkContentType: ['menuButton'] }],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  })

  dropdownmenu.createField('items', {
    name: 'Items',
    type: 'Array',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    items:
      {
        type: 'Link',
        validations:
          [{
            linkContentType:
              ['menuButton']
          }],
        linkType: 'Entry'
      }
  })

  dropdownmenu.changeEditorInterface('name', 'singleLine')
  dropdownmenu.changeEditorInterface('label', 'entryLinkEditor')
  dropdownmenu.changeEditorInterface('items', 'entryLinksEditor')
}
