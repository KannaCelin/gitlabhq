require 'nokogiri'

module GitlabMarkdownHelper
  # Use this in places where you would normally use link_to(gfm(...), ...).
  #
  # It solves a problem occurring with nested links (i.e.
  # "<a>outer text <a>gfm ref</a> more outer text</a>"). This will not be
  # interpreted as intended. Browsers will parse something like
  # "<a>outer text </a><a>gfm ref</a> more outer text" (notice the last part is
  # not linked any more). link_to_gfm corrects that. It wraps all parts to
  # explicitly produce the correct linking behavior (i.e.
  # "<a>outer text </a><a>gfm ref</a><a> more outer text</a>").
  def link_to_gfm(body, url, html_options = {})
    return "" if body.blank?

    escaped_body = if body =~ /\A\<img/
                     body
                   else
                     escape_once(body)
                   end

    user = current_user if defined?(current_user)
    gfm_body = Gitlab::Markdown.render(escaped_body, project: @project, current_user: user, pipeline: :single_line)

    fragment = Nokogiri::HTML::DocumentFragment.parse(gfm_body)
    if fragment.children.size == 1 && fragment.children[0].name == 'a'
      # Fragment has only one node, and it's a link generated by `gfm`.
      # Replace it with our requested link.
      text = fragment.children[0].text
      fragment.children[0].replace(link_to(text, url, html_options))
    else
      # Traverse the fragment's first generation of children looking for pure
      # text, wrapping anything found in the requested link
      fragment.children.each do |node|
        next unless node.text?
        node.replace(link_to(node.text, url, html_options))
      end
    end

    # Add any custom CSS classes to the GFM-generated reference links
    if html_options[:class]
      fragment.css('a.gfm').add_class(html_options[:class])
    end

    fragment.to_html.html_safe
  end

  def markdown(text, context = {})
    return "" unless text.present?

    context[:project] ||= @project
    
    html = Gitlab::Markdown.render(text, context)

    context.merge!(
      current_user:   (current_user if defined?(current_user)),

      # RelativeLinkFilter
      requested_path: @path,
      project_wiki:   @project_wiki,
      ref:            @ref
    )

    Gitlab::Markdown.post_process(html, context)
  end

  def asciidoc(text)
    Gitlab::Asciidoc.render(text,
      project:      @project,
      current_user: (current_user if defined?(current_user)),

      # RelativeLinkFilter
      project_wiki:   @project_wiki,
      requested_path: @path,
      ref:            @ref,
      commit:         @commit
    )
  end

  # Return the first line of +text+, up to +max_chars+, after parsing the line
  # as Markdown.  HTML tags in the parsed output are not counted toward the
  # +max_chars+ limit.  If the length limit falls within a tag's contents, then
  # the tag contents are truncated without removing the closing tag.
  def first_line_in_markdown(text, max_chars = nil, options = {})
    md = markdown(text, options).strip

    truncate_visible(md, max_chars || md.length) if md.present?
  end

  def render_wiki_content(wiki_page)
    case wiki_page.format
    when :markdown
      markdown(wiki_page.content)
    when :asciidoc
      asciidoc(wiki_page.content)
    else
      wiki_page.formatted_content.html_safe
    end
  end

  MARKDOWN_TIPS = [
    "End a line with two or more spaces for a line-break, or soft-return",
    "Inline code can be denoted by `surrounding it with backticks`",
    "Blocks of code can be denoted by three backticks ``` or four leading spaces",
    "Emoji can be added by :emoji_name:, for example :thumbsup:",
    "Notify other participants using @user_name",
    "Notify a specific group using @group_name",
    "Notify the entire team using @all",
    "Reference an issue using a hash, for example issue #123",
    "Reference a merge request using an exclamation point, for example MR !123",
    "Italicize words or phrases using *asterisks* or _underscores_",
    "Bold words or phrases using **double asterisks** or __double underscores__",
    "Strikethrough words or phrases using ~~two tildes~~",
    "Make a bulleted list using + pluses, - minuses, or * asterisks",
    "Denote blockquotes using > at the beginning of a line",
    "Make a horizontal line using three or more hyphens ---, asterisks ***, or underscores ___"
  ].freeze

  # Returns a random markdown tip for use as a textarea placeholder
  def random_markdown_tip
    MARKDOWN_TIPS.sample
  end

  private

  # Return +text+, truncated to +max_chars+ characters, excluding any HTML
  # tags.
  def truncate_visible(text, max_chars)
    doc = Nokogiri::HTML.fragment(text)
    content_length = 0
    truncated = false

    doc.traverse do |node|
      if node.text? || node.content.empty?
        if truncated
          node.remove
          next
        end

        # Handle line breaks within a node
        if node.content.strip.lines.length > 1
          node.content = "#{node.content.lines.first.chomp}..."
          truncated = true
        end

        num_remaining = max_chars - content_length
        if node.content.length > num_remaining
          node.content = node.content.truncate(num_remaining)
          truncated = true
        end
        content_length += node.content.length
      end

      truncated = truncate_if_block(node, truncated)
    end

    doc.to_html
  end

  # Used by #truncate_visible.  If +node+ is the first block element, and the
  # text hasn't already been truncated, then append "..." to the node contents
  # and return true.  Otherwise return false.
  def truncate_if_block(node, truncated)
    if node.element? && node.description.block? && !truncated
      node.inner_html = "#{node.inner_html}..." if node.next_sibling
      true
    else
      truncated
    end
  end

  # Returns the text necessary to reference `entity` across projects
  #
  # project - Project to reference
  # entity  - Object that responds to `to_reference`
  #
  # Examples:
  #
  #   cross_project_reference(project, project.issues.first)
  #   # => 'namespace1/project1#123'
  #
  #   cross_project_reference(project, project.merge_requests.first)
  #   # => 'namespace1/project1!345'
  #
  # Returns a String
  def cross_project_reference(project, entity)
    if entity.respond_to?(:to_reference)
      "#{project.to_reference}#{entity.to_reference}"
    else
      ''
    end
  end
end
