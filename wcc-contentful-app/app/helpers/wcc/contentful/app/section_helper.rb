# frozen_string_literal: true

module WCC::Contentful::App::SectionHelper
  def section_template_name(section)
    section.class.name.demodulize.underscore.sub('section_', '')
  end

  def section_css_name(section)
    section_template_name(section).dasherize
  end

  def section_styles(section)
    section_styles = ['section-' + section_css_name(section)]
    if styles = section.try(:styles)
      section_styles.push(styles.map { |style| style.downcase.gsub(/[^\w]/, '-') })
    elsif style = section.try(:style)
      section_styles.push(style.downcase.gsub(/[^\w]/, '-'))
    else
      section_styles.push('default')
    end
    section_styles
  end
end
