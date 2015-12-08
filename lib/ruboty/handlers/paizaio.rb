#coding:utf-8
require 'json'
require 'net/http'
require 'uri'
require 'open-uri'

#クラス変数を使いたいので、Actionを切り出すことは不可能
module Ruboty
	module Handlers
		class Paizaio < Base
			LANGUAGES=[
                  "c",
                  "cpp",
                  "objective-c",
                  "java",
                  "scala",
				  "swift",
                  "csharp",
                  "go",
                  "haskell",
                  "erlang",
                  "perl",
                  "python",
                  "python3",
                  "ruby",
                  "php",
                  "bash",
                  "r",
                  "javascript",
                  "coffeescript",
                  "vb",
                  "cobol",
                  "fsharp",
                  "d",
                  "clojure",
                  "mysql"
                ]

			def initialize(*__reserved__)
				super
				@input=nil
				@current_submission=nil

				@languages=LANGUAGES
			end
			def read_uri(uri)
				return nil if !uri||uri.empty?
				Kernel.open(uri){|f|
					return f.read
				}
			end

			on /paizaio languages/, name: 'languages', description: 'show languages'
			on /paizaio setinput ?(?<input_uri>\S*)/, name: 'setinput', description: 'set input'
			on /paizaio submit (?<language>\S+) (?<source_uri>\S+) ?(?<input_uri>\S*)/, name: 'submit', description: 'send code via uri'
			on /paizaio view ?(?<id>\S*)/, name: 'view', description: 'view submission'
			def languages(message)
				message.reply @languages.map{|e|e+"\n"}.join
			end
			def setinput(message)
				#input_uri: 入力ファイル(空文字列ならクリア)
				if !message[:input_uri]||message[:input_uri].empty?
					@input=nil
					message.reply 'Input cleared.'
				else
					@input=read_uri(message[:input_uri])
					message.reply 'Input set.'
				end
			end
			def submit(message)
				#language: 言語名(文字列)記号類を除いて最大先頭一致のものを使用する。
				#source_uri: ソースファイル
				#input_uri: 入力ファイル(空文字列ならsetinputの内容を使用)
				input=message[:input_uri]&&!message[:input_uri].empty? ? read_uri(message[:input_uri]) : @input
				#guess lang
				lang=message[:language].downcase.gsub(/[\s\(\)\.]/,'')
				lang=@languages.max_by{|e|
					_e=e.downcase.gsub(/[\s\(\)\.]/,'')
					lang.size.downto(1).find{|i|_e.start_with?(lang[0,i])}||-1
				}

				json={
					language: lang,
					source_code: read_uri(message[:source_uri]),
					input: input,
					longpoll: true,
					longpoll_timeout: 10.0,
				}
				uri=URI.parse('http://api.paiza.io/runners/create')
				Net::HTTP.start(uri.host,uri.port){|http|
					resp=http.post(uri.path,JSON.generate(json),{
						'Content-Type'=>'application/json',
					})
					json=JSON.parse(resp.body)
					#p json
					@current_submission=json['id']
					message.reply 'http://api.paiza.io/runners/get_details?id='+@current_submission
				}
			end
			def view(message)
				#id: paiza.io ID(空文字列なら直前のsubmitで返されたIDを使用)
				#なお、api.paiza.ioのエントリはpaiza.ioのエントリとは異なる模様。コード一覧にも出てこない。
				submission=message[:id]&&!message[:id].empty? ? message[:id] : @current_submission
				resp=JSON.parse Net::HTTP.get URI.parse 'http://api.paiza.io/runners/get_details?id='+submission
				if resp['status']=='running'
					message.reply '[Ruboty::Paizaio] running'
				elsif resp['build_exit_code']!=0
					message.reply '[Ruboty::Paizaio] compile error'
				else
					message.reply resp['stdout']
				end
			end
		end
	end
end
