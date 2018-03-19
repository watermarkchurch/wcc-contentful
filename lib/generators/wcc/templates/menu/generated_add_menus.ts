
import Migration from 'contentful-migration-cli'

export = function (migration: Migration) {
  const menu = migration.createContentType('menu')
    .name('Menu')
    .description('A Menu contains a number of Menu Buttons or other Menus, which ' +
     'will be rendered as drop-downs.')
    .displayField('name') 

  menu.createField('name')
    .name('Menu Name')
    .type('Symbol')
    .required(true)

  menu.createField('topButton')
    .name('Top Button')
    .type('Link')
    .linkType('Entry')
    .validations([
      { 
        linkContentType: [ 'menuButton' ],
        message: 'The Top Button must be a button linking to a URL or page.  ' +
          'If the menu is a dropdown, this button is visible when it is collapsed.'
      }
    ])
  
  menu.createField('items')
    .name('Items')
    .type('Array')
    .items({
      type: 'Link',
      linkType: 'Entry',
      validations: [
        { 
          linkContentType: [ 'menu', 'menuButton' ],
          message: 'The items must be either buttons or drop-down menus'
        }
      ]
    })

  const menuButton = migration.createContentType('menuButton')
    .name('Menu Button')
    .description('A Menu Button is a clickable button that goes on a Menu.  ' +
      'It has a link to a Page or a URL.')
    .displayField('text')

  menuButton.createField('text')
    .name('Text')
    .type('Symbol')
    .required(true)
    .validations([
      { 
        size: { min: 1, max: 60 },
        message: 'A Menu Button should have a very short text field - ideally a ' +
          'single word.  Please limit the text to 60 characters.'
      }
    ])

  menuButton.createField('icon')
    .name('Icon')
    .type('Link')
    .linkType('Asset')
  
  menuButton.createField('externalLink')
    .name('External Link')
    .type('Symbol')
    .validations([
      {
        regexp: { pattern: "^(ftp|http|https):\\/\\/(\\w+:{0,1}\\w*@)?(\\S+)(:[0-9]+)?(\\/|\\/([\\w#!:.?+=&%@!\\-\\/]))?$" },
        message: "The external link must be a URL like 'https://www.watermark.org/'" 
      }
    ])
  
  menuButton.createField('link')
    .name('Page Link')
    .type('Link')
    .linkType('Entry')
    .validations([
      {
        linkContentType: [ 'page' ],
        message: 'The Page Link must be a link to a Page which has a slug.'
      }
    ])
}
