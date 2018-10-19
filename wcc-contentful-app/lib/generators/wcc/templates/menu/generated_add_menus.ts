import Migration from 'contentful-migration';

export = function(migration: Migration, { makeRequest, spaceId, accessToken }) {
  var menu = migration.createContentType('menu', {
    displayField: 'internalTitle',
    name: 'Menu',
    description:
      'A Menu contains a number of Menu Buttons or other Menus, which will be rendered as drop-downs.'
  });

  menu.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true
  });

  menu.createField('name', {
    name: 'Menu Name',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: false
  });

  menu.createField('items', {
    name: 'Items',
    type: 'Array',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    items: {
      type: 'Link',
      validations: [
        {
          linkContentType: ['dropdownMenu', 'dynamicButton', 'menuButton'],
          message: 'The items must be either buttons or drop-down menus.'
        }
      ],
      linkType: 'Entry'
    }
  });

  menu.changeEditorInterface('name', 'singleLine');
  menu.changeEditorInterface('items', 'entryLinksEditor');
  menu.changeEditorInterface('internalTitle', 'singleLine');

  var menubutton = migration.createContentType('menuButton', {
    displayField: 'internalTitle',
    name: 'Menu Button',
    description:
      'A Menu Button is a clickable button that goes on a Menu.  It has a link to a Page or a URL.'
  });

  menubutton.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true
  });

  menubutton.createField('text', {
    name: 'Text',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [
      {
        size: {
          min: 1,
          max: 60
        },
        message:
          'A Menu Button should have a very short text field - ideally a single word.  Please limit the text to 60 characters.'
      }
    ],
    disabled: false,
    omitted: false
  });

  menubutton.createField('icon', {
    name: 'Icon',
    type: 'Link',
    localized: false,
    required: false,
    validations: [
      {
        linkMimetypeGroup: ['image']
      }
    ],
    disabled: false,
    omitted: false,
    linkType: 'Asset'
  });

  menubutton.createField('materialIcon', {
    name: 'Material Icon',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [
      {
        regexp: {
          pattern: '^\\w+$',
          flags: null
        },
        message:
          "The icon name must be one of the icons in Google's Material Design library: https://material.io/tools/icons/"
      }
    ],
    disabled: false,
    omitted: false
  });

  menubutton.createField('externalLink', {
    name: 'External Link',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [
      {
        regexp: {
          pattern:
            '^([^\\s\\:]+):(\\/\\/)?(\\w+:{0,1}\\w*@)?(([^\\s\\/#]+\\.)+[^\\s\\/#]+)(:[0-9]+)?(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))?$|^(\\/|(\\/|\\#)([\\w#!:.?+=&%@!\\-\\/]+))$'
        },
        message:
          "The external link must be a URL like 'https://www.watermark.org/', a mailto url like 'mailto:info@watermark.org', or a relative URL like '#location-on-page'"
      }
    ],
    disabled: false,
    omitted: false
  });

  menubutton.createField('link', {
    name: 'Page Link',
    type: 'Link',
    localized: false,
    required: false,
    validations: [
      {
        linkContentType: ['page', 'page-v2'],
        message: 'The Page Link must be a link to a Page which has a slug.'
      }
    ],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  });

  menubutton.createField('sectionLink', {
    name: 'Section Link',
    type: 'Link',
    localized: false,
    required: false,
    validations: [
      {
        linkContentType: [
          'section-conference-speakers',
          'section-email-signup',
          'section-event-schedule',
          'section-faq',
          'section-hero',
          'section-hotels',
          'section-pricing',
          'section-social-links',
          'section-video-about'
        ]
      }
    ],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  });

  menubutton.createField('style', {
    name: 'Style',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [
      {
        in: ['default', 'white-border']
      }
    ],
    disabled: false,
    omitted: false
  });

  menubutton.changeEditorInterface('text', 'singleLine');
  menubutton.changeEditorInterface('icon', 'assetLinkEditor');
  menubutton.changeEditorInterface('externalLink', 'singleLine', {
    helpText:
      'Provide a URL to something on another website, a `mailto:` link to an email address, or a deep link into an app.'
  });
  menubutton.changeEditorInterface('link', 'entryLinkEditor');
  menubutton.changeEditorInterface('internalTitle', 'singleLine');
  menubutton.changeEditorInterface('style', 'dropdown');
  menubutton.changeEditorInterface('sectionLink', 'entryLinkEditor', {
    helpText:
      'If provided, this will link the user to the specific section on a page.  You must use this in combination with Page Link.'
  });
  menubutton.changeEditorInterface('materialIcon', 'singleLine', {
    helpText:
      'As an alternative to the Media icon, you can select an icon from here: https://material.io/tools/icons/'
  });

  var dropdownmenu = migration.createContentType('dropdownMenu', {
    displayField: 'internalTitle',
    name: 'Dropdown Menu',
    description:
      'A Dropdown Menu can be attached to a main menu to show additional menu items on click.'
  });

  dropdownmenu.createField('internalTitle', {
    name: 'Internal Title (Contentful Only)',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: true
  });

  dropdownmenu.createField('name', {
    name: 'Menu Name',
    type: 'Symbol',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  });

  dropdownmenu.createField('label', {
    name: 'Menu Label',
    type: 'Link',
    localized: false,
    required: false,
    validations: [
      {
        linkContentType: ['dynamicButton', 'menuButton']
      }
    ],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  });

  dropdownmenu.createField('items', {
    name: 'Items',
    type: 'Array',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    items: {
      type: 'Link',
      validations: [
        {
          linkContentType: ['dynamicButton', 'menuButton']
        }
      ],
      linkType: 'Entry'
    }
  });

  dropdownmenu.changeEditorInterface('name', 'singleLine', {
    helpText:
      "If you don't set a menu label, this is the text that will appear on the button that opens the dropdown menu.  If you do set a menu label, that will control the text."
  });
  dropdownmenu.changeEditorInterface('label', 'entryLinkEditor');
  dropdownmenu.changeEditorInterface('items', 'entryLinksEditor');
  dropdownmenu.changeEditorInterface('internalTitle', 'singleLine');

  var menuitem = migration.createContentType('MenuItem', {
    displayField: 'title',
    name: 'MenuItem',
    description: ''
  });

  menuitem.createField('title', {
    name: 'Title',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [{ unique: true }],
    disabled: false,
    omitted: false
  });

  menuitem.createField('submenu', {
    name: 'Submenu',
    type: 'Array',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false,
    items: {
      type: 'Link',
      validations: [
        {
          linkContentType: ['submenu']
        }
      ],
      linkType: 'Entry'
    }
  });

  menuitem.createField('url', {
    name: 'URL',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [],
    disabled: false,
    omitted: false
  });

  menuitem.createField('page', {
    name: 'Page',
    type: 'Link',
    localized: false,
    required: false,
    validations: [
      {
        linkContentType: ['blog', 'event', 'location', 'page']
      }
    ],
    disabled: false,
    omitted: false,
    linkType: 'Entry'
  });

  menuitem.createField('order', {
    name: 'Order',
    type: 'Integer',
    localized: false,
    required: false,
    validations: [],
    disabled: false,
    omitted: false
  });

  menuitem.changeEditorInterface('title', 'singleLine');
  menuitem.changeEditorInterface('submenu', 'entryCardsEditor', {
    bulkEditing: false
  });
  menuitem.changeEditorInterface('url', 'singleLine');
  menuitem.changeEditorInterface('page', 'entryLinkEditor');
  menuitem.changeEditorInterface('order', 'numberEditor');

  var divider = migration.createContentType('divider', {
    displayField: 'style',
    name: 'Divider',
    description:
      'A Divider just puts a separator between elements.  This can be a `<hr />` HTML element, or sometimes a Pipe character `|` depending on the context.'
  });

  divider.createField('style', {
    name: 'Style',
    type: 'Symbol',
    localized: false,
    required: true,
    validations: [
      { unique: true },
      {
        in: ['divider', 'thick divider']
      }
    ],
    disabled: false,
    omitted: false
  });

  divider.changeEditorInterface('style', 'radio');
};
