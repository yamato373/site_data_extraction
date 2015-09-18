require 'nokogiri'
require 'open-uri'

METHOD = 'https://'
HOST = 'freelance.levtech.jp'
PATH = '/project/search/'
BASE_URL = METHOD + HOST
PAGE_MAX = 20 # １ページに表示される最大案件数

### スキル及び業種集計クラス
# スキルか業種ごとのデータを保持する為に使用する
class Job
  def initialize(jab_name)
    # スキル名及び業種名
    @job_name = jab_name
    # 案件数
    @total = 0
    # 単価を合計しておく一時変数
    @sum = 0
    # 最高単価
    @maximum = 0
    # 最低単価
    @minimum = 0
  end

  attr_accessor :job_name, :total, :maximum, :minimum

  # 同じスキルか業種が出てきたときに呼ぶメソッド
  def count(price)
    price
    @total += 1
    @sum += price

    if @maximum < price
      @maximum = price
    end

    if @minimum == 0 || @minimum > price
      @minimum = price
    end
  end

  # スキルか業種の平均単価を取得する
  def average
    @sum / @total
  end

  # スキルか業種の結果１行をCSVで出力する
  def get_csv
    @job_name + ',' +
        @total.to_s + ',' +
        @minimum.to_s + ',' +
        @maximum.to_s + ',' +
        average.to_s +
        "\n"
  end
end

jobs = {}
businesses = {}

#️ 案件総件数の取得
doc = Nokogiri::HTML(open(BASE_URL + PATH))
          .xpath("//span[@class='searchDetail__txtResult__txtBold']")
full_count = doc.text.to_i
# 案件リストページが何ページあるのか取得
page_count = full_count / PAGE_MAX

# 1ページずつの処理を行う
page_count.times do |page|
  if page == 0
    search_url = BASE_URL + PATH
  else
    # 2ページ以降はURLを組み立てる
    page += 1
    search_url = BASE_URL + PATH + 'p' + page.to_s + '/'
  end

  # HTMLを取得する
  doc = Nokogiri::HTML(open(search_url))

  # 企業カセットを取得しやすくする
  items = doc.xpath("//div[@class='projectDetail']")

  puts '-----------------------------------------------------------------------------------'
  puts '案件リスト'
  puts '-----------------------------------------------------------------------------------'

  # 企業カセットごとに処理をする
  items.each do |node|

    # 案件名を取得して出力
    puts node.xpath('h3/a').text

    # 詳細ページのURLを取得して出力
    puts BASE_URL + node.xpath('h3/a').attribute('href')

    # 案件が月単価の場合かフラグを持つ
    price_type = node.xpath('div/p').text.include?('月')

    # 単価を取得して出力
    puts price = node.xpath('div/p/span').text

    # 項目は最大で5個あるので５回ループ
    5.size.times do |count|
      count += 1

      # 項目名を取得
      head = node.xpath('table/tr[' + count.to_s + ']/th[1]').text.strip

      case head
        when '職務内容', '最寄り駅', '必須スキル'
          puts '【' + head + '】'
          # 項目の内容を取得
          puts node.xpath('table/tr[' + count.to_s + ']/td[1]').text.strip

        when '募集職種', '開発環境'
          puts '【' + head + '】'
          skills = node.xpath('table/tr[' + count.to_s + ']/td[1]/p/a')
          # スキルか業種分だけループする
          skills.each do |skill|
            jab_name = skill.text

            print skill.text + ' '

            # 月単価の場合のみ集計する
            if price_type
              if head == '募集職種'
                # 初めて出来てきた業種の場合インスタンス化してハッシュに詰める
                unless businesses.key?(jab_name)
                  businesses[jab_name] = Job.new(jab_name)
                end
                # countメソッドをコールしてデータを保持する
                businesses[jab_name].count(price.delete(',').delete('円').delete('～').to_i)
              elsif head == '開発環境'
                # 初めて出来てきたスキルの場合インスタンス化してハッシュに詰める
                unless jobs.key?(jab_name)
                  jobs[jab_name] = Job.new(jab_name)
                end
                # countメソッドをコールしてデータを保持する
                jobs[jab_name].count(price.delete(',').delete('円').delete('～').to_i)
              end
            else
              puts '※この案件は月単価ではないので集計対象外です'
            end
          end
          puts ' '
        else
      end
    end

    puts '-----------------------------------------------------------------------------------'
  end
end

# 集計データの出力処理
def output(format, jobs)
  open('levtech_jab_' + format + '_' + DateTime.now.strftime("%Y-%m-%d-%H-%M-%S") + '.csv','w:UTF-8') do |file|
    header = ''
    case format
      when 'skill'
        header = '技術'
      when 'type'
        header = '職種'
      else
    end

    file.print(header + ',' +
                   '案件数' + ',' +
                   '最安単価' + ',' +
                   '最高単価' + ',' +
                   '平均単価' +
                   "\n")

    puts '-----------------------------------------------------------------------------------'
    puts header + '別'
    puts '-----------------------------------------------------------------------------------'

    jobs.each_value do |val|
      file.print(val.get_csv)
      print val.job_name
      print "\t合計:" + val.total.to_s
      print "\t最安:" + val.minimum.to_s
      print "\t最高:" + val.maximum.to_s
      print "\t平均:" + val.average.to_s
      print "\n"
    end
  end
end

output('skill', jobs)
output('type', businesses)
