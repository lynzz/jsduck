require 'rubygems'
require 'strscan'
require 'rdiscount'
require 'jsduck/logger'
require 'jsduck/inline/link'
require 'jsduck/inline/img'
require 'jsduck/inline/video'

module JsDuck

  # Formats doc-comments
  class DocFormatter

    def initialize(relations={}, opts={})
      @images = []

      @inline_link = Inline::Link.new(opts)
      @inline_link.relations = relations
      @inline_img = Inline::Img.new(opts)
      @inline_video = Inline::Video.new(opts)

      @example_annotation_re = /<pre><code>\s*@example( +[^\n]*)?\s+/m
    end

    # Sets base path to prefix images from {@img} tags.
    def img_path=(path)
      @inline_img.base_path = path
    end

    # Returns list of all image paths gathered from {@img} tags.
    def images
      @inline_img.images
    end

    # Sets up instance to work in context of particular class, so
    # that when {@link #blah} is encountered it knows that
    # Context#blah is meant.
    def class_context=(cls)
      @inline_link.class_context = cls
    end

    # Sets up instance to work in context of particular doc object.
    # Used for error reporting.
    def doc_context=(doc)
      @inline_video.doc_context = doc
      @inline_link.doc_context = doc
    end

    # Returns the current documentation context
    def doc_context
      @inline_link.doc_context
    end

    # JsDuck::Relations for looking up class names.
    #
    # When auto-creating class links from CamelCased names found from
    # text, we check the relations object to see if a class with that
    # name actually exists.
    def relations=(relations)
      @inline_link.relations = relations
    end

    # Replaces {@link} and {@img} tags, auto-generates links for
    # recognized classnames.
    #
    # Replaces {@link Class#member link text} in given string with
    # HTML from @link_tpl.
    #
    # Replaces {@img path/to/image.jpg Alt text} with HTML from @img_tpl.
    #
    # Adds 'inline-example' class to code examples beginning with @example.
    #
    # Additionally replaces strings recognized as ClassNames or
    # #members with links to these classes or members.  So one doesn't
    # even need to use the @link tag to create a link.
    def replace(input)
      s = StringScanner.new(input)
      out = ""

      # Keep track of the nesting level of <a> tags. We're not
      # auto-detecting class names when inside <a>. Normally links
      # shouldn't be nested, but just to be extra safe.
      open_a_tags = 0

      while !s.eos? do
        if substitute = @inline_link.replace(s)
          out += substitute
        elsif substitute = @inline_img.replace(s)
          out += substitute
        elsif substitute = @inline_video.replace(s)
          out += substitute
        elsif s.check(/[{]/)
          # There might still be "{" that doesn't begin {@link} or {@img} - ignore it
          out += s.scan(/[{]/)
        elsif s.check(@example_annotation_re)
          # Match possible classnames following @example and add them
          # as CSS classes inside <pre> element.
          s.scan(@example_annotation_re) =~ @example_annotation_re
          css_classes = ($1 || "").strip
          out += "<pre class='inline-example #{css_classes}'><code>"
        elsif s.check(/<a\b/)
          # Increment number of open <a> tags.
          open_a_tags += 1
          out += s.scan_until(/>|\Z/)
        elsif s.check(/<\/a>/)
          # <a> closed, auto-detection may continue when no more <a> tags open.
          open_a_tags -= 1
          out += s.scan(/<\/a>/)
        elsif s.check(/</)
          # Ignore all other HTML tags
          out += s.scan_until(/>|\Z/)
        else
          # Replace class names in the following text up to next "<" or "{"
          # but only when we're not inside <a>...</a>
          text = s.scan(/[^{<]+/)
          out += open_a_tags > 0 ? text : @inline_link.create_magic_links(text)
        end
      end
      out
    end

    # Creates a link based on the link template.
    def link(cls, member, anchor_text, type=nil, static=nil)
      @inline_link.link(cls, member, anchor_text, type, static)
    end

    # Formats doc-comment for placement into HTML.
    # Renders it with Markdown-formatter and replaces @link-s.
    def format(input)
      # In ExtJS source "<pre>" is often at the end of paragraph, not
      # on its own line.  But in that case RDiscount doesn't recognize
      # it as the beginning of <pre>-block and goes on parsing it as
      # normal Markdown, which often causes nested <pre>-blocks.
      #
      # To prevent this, we always add extra newline before <pre>.
      input.gsub!(/([^\n])<pre>/, "\\1\n<pre>")

      # But we remove trailing newline after <pre> to prevent
      # code-blocks beginning with empty line.
      input.gsub!(/<pre>(<code>)?\n?/, "<pre>\\1")

      replace(RDiscount.new(input).to_html)
    end

  end

end
