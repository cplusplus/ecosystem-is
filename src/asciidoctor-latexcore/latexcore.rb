# frozen_string_literal: true

require 'cgi'

module AsciidoctorLaTexCore

	class LaTexCoreConverter < Asciidoctor::Converter::Base
		register_for 'latexcore'

		LF = "\n"

		IGNORED_SCOPES = Set[
			# Built-in roles
			# 'underline',
			'overline',
			'line-through',
			'nobreak',
			'nowrap',
			'pre-wrap',
			# Common roles
			'right'
		]

		def initialize backend, opts = {}
			@backend = backend
			init_backend_traits basebackend: 'latexcore', filetype: 'tex', outfilesuffix: '.tex', supports_templates: true
		end

		def convert_document node
			@tex_index = node.attr 'texindex'
			@in_literal = 0
			@in_bibliography = 0
			@tex_source_highlighter = node.attr 'tex-source-highlighter'

			tex_root = node.attr 'texroot'

			# root name
			result = []
			result << %(\
\%!TEX root = #{tex_root}
) if tex_root

			result << %(\
% Generated file. Do not edit.
)

			copyright = node.attr 'copyright'
			license = node.attr 'license'
			if copyright || license
				if copyright
					result << %(% #{copyright})
				end
				if license
					result << %(% #{license})
				end
				result << %()
			end

			if node.title
				if ! node.attr? 'texbare'
					if role?(node, 'chapter')
						# plain chapter
						result << %(\
\\chapter{#{texify(node.title.strip)}}
)
					else
						# section 0
						result << gen_section_title(node)
					end
				end
			end

			# content
			result << %(\
#{node.content})

			result.join LF
		end

		def convert_embedded node
			result = []
			result << node.content
			result.join LF
		end

		def convert_section node
			result = []
			result << gen_section_title(node)
			result << %(\
#{node.content})
			result.join LF
		end

		def convert_admonition node
			result = []
			name = (node.role) ? (node.role[0]) : (node.attr 'name')
			result << %(\
\\begin{#{name}}
#{node.content}
\\end{#{name}}
)
			result.join LF
		end

		def convert_colist node
			result = []
			result.join LF
		end

		def convert_dlist node
			result = []
			is_bnf = node.option?('bnf') || role?(node,'bnf')
			if is_bnf
				result << %(\\begin{bnf})
			elsif node.option?('description')
				result << %(\\begin{description})
			end
			node.items.each do |terms, dd|
				if is_bnf
					result << %(\n\\nontermdef{#{terms[0].text}}\\br)
					result << texify(dd.text.gsub("\n", "\\br\n")) if dd.text?
					result << dd.content.join("\\br\n") if dd.blocks?
				elsif node.option?('description')
					result << %(\\item[#{texify(terms[0].text)}] #{texify(dd.text.gsub("\n", "\\br\n"))}) if dd.text?
					result << %(\\item[#{texify(terms[0].text)}] #{dd.content.join("\\br\n")}) if dd.blocks?
				else
					result << %(\n\\definition{#{terms[0].text}}{#{node.id}})
					result << texify(dd.text) if dd.text?
					result << dd.content if dd.blocks?
				end
			end
			if is_bnf
				result << %(\\end{bnf})
			elsif node.option?('description')
				result << %(\\end{description})
			end
			result.join LF
		end

		def convert_example node
			result = []
			result << %(\
\\begin{example}
#{texify(node.content)}
\\end{example}
)
			result.join LF
		end

		def convert_floating_title node
			result = []
			result.join LF
		end

		def convert_image node
			result = []
			result.join LF
		end

		def convert_listing node
			result = []
			lst_lang = ''
			lst_tag = ''
			if node.attributes.key? 'language'
				lst_lang = node.attributes['language']
			end
			lst_args = ''
			if @tex_source_highlighter == 'minted'
				lst_tag = 'minted'
				lst_args = %({#{lst_lang}})
			elsif @tex_source_highlighter == 'listings'
				lst_tag = 'lstlisting'
				# lst_args = %([language=#{lst_lang}])
			end
			result << %(
\\begin{#{lst_tag}}#{lst_args}
#{texify(node.content)}
\\end{#{lst_tag}}
)
			result.join LF
		end

		def convert_literal node
			@in_literal += 1
			result = []
			if ! node.option?('nonum')
				result << %(\\pnum)
			end
			lst_tag = ''
			lst_args = ''
			if @tex_source_highlighter == 'minted'
				lst_tag = 'minted'
				lst_args = '{}'
			elsif @tex_source_highlighter == 'listings'
				lst_tag = 'lstlisting'
			end
			result << %(\
\\begin{#{lst_tag}}{}
#{texify(node.content)}
\\end{#{lst_tag}}
)
			result.join LF
			@in_literal -= 1
			result
		end

		def convert_sidebar node
			result = []
			result.join LF
		end

		def convert_olist node
			result = []
			if node.option?('bibliography')
				@in_bibliography += 1
			end
			options = []
			# result << %(% #{node.list_marker_keyword})
			if node.list_marker_keyword == 'a'
				options << %(label=\\alph*.)
			elsif node.list_marker_keyword == 'A'
				options << %(label=\\Alph*.)
			elsif node.list_marker_keyword == 'i'
				options << %(label=\\roman*.)
			elsif node.list_marker_keyword == 'I'
				options << %(label=\\Roman*.)
			else
				options << %(label=\\arabic*.)
			end
			result << "\\begin{enumerate}[#{options.join ", "}]\n"
			node.items.map do |item|
				result << %(\\item #{texify(item.text)}\n) if item.text?
				result << texify(item.content) if item.blocks?
			end
			result << "\\end{enumerate}\n"
			if node.option?('bibliography')
				@in_bibliography -= 1
			end
			result.join LF
		end

		def convert_open node
			result = []
			if role?(node)
				result << %(\\begin{#{role?(node)}})
			end
			result << texify(node.content)
			if role?(node)
				result << %(\\end{#{role?(node)}}\n)
			end
			result.join LF
		end

		def convert_page_break node
			'\\newpage\n'
		end

		def convert_paragraph node
			result = []
			if role?(node, 'itemdescr')
				result << %(
\\begin{itemdescr}
#{texify(node.content).gsub(/\\pnum/, "\n\\pnum")}
\\end{itemdescr}
)
			elsif node.option?('nonum')
				result << %(\
#{texify(node.content)}
)
			else
				result << %(\
\\pnum
#{texify(node.content)}
)
			end
			result.join LF
		end

		alias convert_pass content_only
		alias convert_preamble content_only

		def convert_quote node
			result = []
			result.join LF
		end

		def convert_stem node
			result = []
			result.join LF
		end

		def convert_table node
			result = []
			result.join
		end

		def convert_thematic_break node
		end

		alias convert_toc skip

		def convert_ulist node
			result = []
			result << "\\begin{itemize}\n"
			node.items.map do |item|
				result << %(\\item #{texify(item.text)}\n)
			end
			result << "\\end{itemize}\n"
			result.join LF
		end

		def convert_verse node
			result = []
			result.join LF
		end

		alias convert_video skip

		def convert_inline_anchor node
			case node.type
			when :xref
				node_refid = node.attributes['refid']
				root_doc = get_root_document node
				ref = root_doc.resolve_id(node_refid)
				iref = ref ? ref.xreftext : (node.text ? node.text : node_refid)
				%((\\ref{#{texify_iref(iref)}}))
			when :link
				if node.option?('input')
					%(\\input{#{node.target}})
				elsif node.target.start_with?("mailto:")
					node.text
				else
					%(\\url{#{node.target}})
				end
			when :ref
				%(\\label{#{node.id}})
			when :bibref
				%(\\label{#{node.id}})
			else
				logger.warn %(unknown anchor type: #{node.type.inspect})
				nil
			end
		end

		def convert_inline_break node
			%(#{node.text})
		end

		alias convert_inline_button skip

		def convert_inline_callout node
			%(#{node.text})
		end

		def convert_inline_footnote node
			%(#{node.text})
		end

		alias convert_inline_image skip

		def convert_inline_indexterm node
			if node.type == :visible
				%(\\index[#{@tex_index}]{#{texify(node.text)}}#{texify(node.text)})
			else
				%(\\index[#{@tex_index}]{#{texify(node.attr('terms')[0])}})
			end
		end

		def convert_inline_kbd node
		end

		def convert_inline_menu node
		end

		def convert_inline_quoted node
			q = (@in_literal > 0) ? "@" : ""
			case node.type
			when :emphasis
				%(#{q}\\emph{#{texify(node.text)}}#{q})
			when :strong
				%(#{q}\\textbf{#{texify(node.text)}}#{q})
			when :monospaced
				%(#{q}\\verb|#{texify(node.text)}|#{q})
			when :single
				%(‘#{texify(node.text)}’)
			when :double
				%(“#{texify(node.text)}”)
			else
				if IGNORED_SCOPES.include?(role?(node))
					nil
				elsif role?(node, 'iref')
					%(#{q}\\ref{#{texify_iref(node.text)}}#{q})
				elsif role?(node, 'fldname')
					%(#{q}\\pnum#{q} #{q}\\fldname#{q})
				elsif role?(node, 'fldtype')
					%(#{q}\\pnum#{q} #{q}\\fldtype#{q})
				elsif role?(node, 'fldval')
					%(#{q}\\pnum#{q} #{q}\\fldval#{q})
				elsif role?(node, 'flddesc')
					%(#{q}\\pnum#{q} #{q}\\flddesc#{q})
				elsif role?(node, 'item')
					%(#{q}\\item[#{texify_iref(node.text)}]#{q})
				elsif role?(node, 'Cpp')
					%(#{q}\\Cpp{}#{q})
				elsif role? node
					%(#{q}\\#{role? node}{#{texify(node.text)}}#{q})
				else
					texify(node.text)
				end
			end
		end

		private

		def texify str
			if str
				str.gsub(/&#([0-9]+);/){ $1.to_i.chr(Encoding::UTF_8) }.rstrip
				.gsub(/&lt;/){ '<' }
				.gsub(/&gt;/){ '>' }
			else
				''
			end
		end

		def texify_iref str
			str = texify(str).sub(/^\(\[/,'').sub(/\]\)$/,'')
		end

		def get_root_document node
			while (node = node.document).nested?
				node = node.parent_document
			end
			node
		end

		def role? node, role_name = nil
			if role_name
				(node.has_role? role_name) ? role_name : nil
			elsif node.role
				node.roles[0]
			else
				nil
			end
		end

		def gen_section_title node
			result = []
			node_level = node.level - (node.document.attributes['leveldedent'] || '0').to_i
			node_ref = node.id
			# node_ref = node.reftext if node.reftext?
			node_title = node.title.strip
			if role?(node, 'ignore')
				nil
			elsif role?(node, 'infannex')
				result << %(\
\% #{node_title}
\\infannex{#{node_ref}}{#{node_title}}
)
			else
				result << %(\
\% #{node_title}
\\rSec#{node_level}[#{node_ref}]{#{node_title}}
)
			end
			return result
		end
	end

end # AsciidoctorLaTexCore

=begin
Copyright René Ferdinand Rivera Morell
Distributed under the Boost Software License, Version 1.0.
(See copy at http://www.boost.org/LICENSE_1_0.txt)
=end
