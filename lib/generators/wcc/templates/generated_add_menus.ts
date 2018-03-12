
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
  
  menu.createField('icon')
    .name('Icon')
    .type('Link')
    .linkType('Asset')
  
  menu.createField('buttons')
    .name('Buttons')
    .type('Array')
    .items({
      type: 'Link',
      linkType: 'Entry',
      validations: [
        { 
          linkContentType: [ 'menu', 'menuButton' ],
          message: 'The menu buttons must be either buttons or drop-down menus'
        }
      ]
    })

  const menuButton = migration.createContentType('menuButton')
    .name('Menu Button')
    .description('A Menu Button is a clickable button that goes on a Menu.  ' +
      'It has a link to a Page or a URL.')
    .displayField('title')

  menuButton.createField('title')
    .name('Title')
    .type('Symbol')
    .required(true)
    .validations([
      { 
        size: { min: 1, max: 60 },
        message: 'A Menu Button should have a very short title - ideally a ' +
          'single word.  Please limit the title to 60 characters.'
      }
    ])
  
  menu.createField('externalLink')
    .name('External Link')
    .type('Symbol')
    .validations([
      {
        regexp: { pattern: "^(ftp|http|https):\\/\\/(\\w+:{0,1}\\w*@)?(\\S+)(:[0-9]+)?(\\/|\\/([\\w#!:.?+=&%@!\\-\\/]))?$" },
        message: "The external link must be a URL like 'https://www.watermark.org/'" 
      }
    ])
  
  menu.createField('link')
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
