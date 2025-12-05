import requests
import time
import pycountry
from pycountry_convert import country_alpha2_to_continent_code, convert_continent_code_to_continent_name

# ================= 配置区域 =================
API_KEY = 'cc3819ee96a952230259d98026e1c5c3'  # 替换为你的 Key
LANGUAGE = 'en-US'
YEARS_TO_FETCH = [2020, 2021, 2022, 2023, 2024]
MOVIES_PER_YEAR = 5  # 为了测试先设为 5，正式跑可以设为 20 或 50
START_TITLE_ID = 20000 # alt_titles 表的主键起始 ID，防止与现有数据冲突

# ================= 全局缓存 =================
# 使用字典进行去重，键为数据库的主键
data_store = {
    "countries": {},  # key: country_code
    "movies": {},     # key: movieid
    "people": {},     # key: peopleid
    "credits": set(), # Set of tuples (movieid, peopleid, credited_as)
    "alt_titles": []  # List of tuples
}

# 辅助：SQL 字符串转义处理
def sql_safe(val):
    """
    将 Python 数据转换为 SQL 安全的字符串格式
    """
    if val is None:
        return "NULL"
    if isinstance(val, str):
        # 将单引号替换为两个单引号 (Postgres/SQL 标准转义)
        safe_str = val.replace("'", "''")
        return f"'{safe_str}'"
    return str(val)

# 辅助：API 请求 (带重试)
def fetch_url(url, params=None):
    if params is None: params = {}
    params['api_key'] = API_KEY
    for _ in range(3):
        try:
            r = requests.get(url, params=params, timeout=10)
            if r.status_code == 429:
                time.sleep(int(r.headers.get("Retry-After", 5)) + 1)
                continue
            r.raise_for_status()
            return r.json()
        except Exception as e:
            print(f"Error: {e}")
            time.sleep(1)
    return None

# ================= 数据处理逻辑 =================

def process_country(country_code):
    """处理国家：确保代码小写，洲大写"""
    # 强制转为 ISO 两位代码并小写 (符合示例 'in', 'cd')
    code_lower = country_code.lower()
    code_upper = country_code.upper() # 用于 pycountry 查询

    if code_lower in data_store["countries"]:
        return code_lower

    # 获取全名
    try:
        c_obj = pycountry.countries.get(alpha_2=code_upper)
        name = getattr(c_obj, 'common_name', c_obj.name)
    except:
        name = f"Country {code_upper}"

    # 获取洲并大写 (符合示例 'AFRICA')
    try:
        cont_code = country_alpha2_to_continent_code(code_upper)
        cont_name = convert_continent_code_to_continent_name(cont_code).upper()
    except:
        cont_name = "UNKNOWN"

    # 截断
    if len(name) > 50: name = name[:50]
    
    data_store["countries"][code_lower] = {
        "code": code_lower,
        "name": name,
        "continent": cont_name
    }
    return code_lower

def process_person(person_id, name):
    """处理人物：拆分名字，处理出生日期约束"""
    if person_id in data_store["people"]:
        return True

    url = f"https://api.themoviedb.org/3/person/{person_id}"
    data = fetch_url(url)
    if not data: return False

    # 约束：Born 必须存在且为整数
    birthday = data.get('birthday')
    if not birthday: return False 
    try:
        born_year = int(birthday.split('-')[0])
    except: return False

    died_year = None
    if data.get('deathday'):
        try:
            died_year = int(data.get('deathday').split('-')[0])
        except: pass

    # 名字拆分逻辑
    # 示例: 'Barry Newman' -> First: 'Barry', Sur: 'Newman'
    # 如果只有 'Zendaya' -> First: NULL, Sur: 'Zendaya' (假设Surname Not Null)
    parts = name.strip().split()
    if len(parts) == 1:
        first_name = None
        surname = parts[0]
    else:
        surname = parts[-1] # 最后一个词做姓
        first_name = " ".join(parts[:-1]) # 前面的做名

    # 截断
    if first_name and len(first_name) > 30: first_name = first_name[:30]
    if len(surname) > 30: surname = surname[:30]

    # 性别: TMDB 1=Female, 2=Male. 示例使用 'M'/'F'/'?'
    gender_map = {1: 'F', 2: 'M'}
    gender = gender_map.get(data.get('gender'), '?')

    data_store["people"][person_id] = {
        "id": person_id,
        "first": first_name,
        "sur": surname,
        "born": born_year,
        "died": died_year,
        "gender": gender
    }
    return True

def run_etl():
    print("开始获取数据...")
    global_title_id = START_TITLE_ID

    for year in YEARS_TO_FETCH:
        print(f"正在处理年份: {year}")
        res = fetch_url("https://api.themoviedb.org/3/discover/movie", 
                       {'primary_release_year': year, 'sort_by': 'popularity.desc', 'vote_count.gte': 50})
        
        if not res: continue
        movies = res.get('results', [])[:MOVIES_PER_YEAR]

        for m in movies:
            mid = m['id']
            title = m['title']
            
            # 获取详情
            details = fetch_url(f"https://api.themoviedb.org/3/movie/{mid}")
            if not details: continue

            # 1. 检查国家
            if not details.get('production_countries'): continue
            raw_country = details['production_countries'][0]['iso_3166_1']
            if len(raw_country) > 2: continue # 过滤异常代码
            
            country_code = process_country(raw_country) # 获取并存入 store

            # 2. 存入 Movie
            runtime = details.get('runtime', 0)
            if runtime is None: runtime = 0
            
            if len(title) > 100: title = title[:100]

            data_store["movies"][mid] = {
                "id": mid,
                "title": title,
                "country": country_code,
                "year": year,
                "runtime": int(runtime)
            }
            print(f"  - 获取电影: {title}")

            # 3. 获取 Alt Titles (别名)
            # TMDB 的别名接口
            alt_res = fetch_url(f"https://api.themoviedb.org/3/movie/{mid}/alternative_titles")
            if alt_res:
                # 只取前2个别名以免数据太多
                for alt in alt_res.get('titles', [])[:2]:
                    alt_title = alt['title']
                    if len(alt_title) > 250: continue
                    data_store["alt_titles"].append({
                        "titleid": global_title_id,
                        "movieid": mid,
                        "title": alt_title
                    })
                    global_title_id += 1

            # 4. 获取 Credits (演职员)
            cred_res = fetch_url(f"https://api.themoviedb.org/3/movie/{mid}/credits")
            if cred_res:
                # 演员 (Top 3)
                for cast in cred_res.get('cast', [])[:3]:
                    pid = cast['id']
                    if process_person(pid, cast['name']):
                        data_store["credits"].add((mid, pid, 'A'))
                
                # 导演 (Top 1)
                for crew in cred_res.get('crew', []):
                    if crew['job'] == 'Director':
                        pid = crew['id']
                        if process_person(pid, crew['name']):
                            data_store["credits"].add((mid, pid, 'D'))
                        break
            
            time.sleep(0.1) # 稍微限流

    generate_sql_file()

def generate_sql_file():
    print("\n正在生成 insert_data.sql 文件...")
    with open('insert_data.sql', 'w', encoding='utf-8') as f:
        f.write("BEGIN TRANSACTION;\n")
        f.write("-- Disable FK checks temporarily if permissions allow, strictly ordered otherwise\n")
        # 注意: Postgres 中通常不需要 PRAGMA，但如果你的工具支持，或者为了兼容性保留
        # 下面严格按照依赖顺序插入
        
        # 1. Countries
        f.write("\n-- Table: countries\n")
        for code, data in data_store["countries"].items():
            # 格式: INSERT INTO countries VALUES('cd','Congo Kinshasa','AFRICA');
            line = f"INSERT INTO countries VALUES({sql_safe(data['code'])}, {sql_safe(data['name'])}, {sql_safe(data['continent'])});"
            f.write(line + "\n")

        # 2. Movies
        f.write("\n-- Table: movies\n")
        for mid, data in data_store["movies"].items():
            # 格式: INSERT INTO movies VALUES(23,'Title','in',1985,148);
            line = f"INSERT INTO movies VALUES({data['id']}, {sql_safe(data['title'])}, {sql_safe(data['country'])}, {data['year']}, {data['runtime']});"
            f.write(line + "\n")

        # 3. People
        f.write("\n-- Table: people\n")
        for pid, data in data_store["people"].items():
            # 格式: INSERT INTO people VALUES(10646,'Anthony','Newley',1931,1999,'M');
            # 注意 first_name 可以为 NULL
            line = f"INSERT INTO people VALUES({data['id']}, {sql_safe(data['first'])}, {sql_safe(data['sur'])}, {data['born']}, {sql_safe(data['died'])}, {sql_safe(data['gender'])});"
            f.write(line + "\n")

        # 4. Credits
        f.write("\n-- Table: credits\n")
        for mid, pid, role in data_store["credits"]:
            # 格式: INSERT INTO credits VALUES(2170,15580,'A');
            # 必须确保 movie 和 person 都已经插入 (我们上面的逻辑保证了这点，除非 person 信息不全被过滤了)
            # 再次检查依赖完整性 (Python 端过滤)
            if mid in data_store["movies"] and pid in data_store["people"]:
                line = f"INSERT INTO credits VALUES({mid}, {pid}, '{role}');"
                f.write(line + "\n")

        # 5. Alt Titles
        f.write("\n-- Table: alt_titles\n")
        for item in data_store["alt_titles"]:
            # 格式: INSERT INTO alt_titles VALUES(1441,8580,'Take Off');
            if item['movieid'] in data_store["movies"]:
                line = f"INSERT INTO alt_titles VALUES({item['titleid']}, {item['movieid']}, {sql_safe(item['title'])});"
                f.write(line + "\n")

        f.write("COMMIT;\n")
    
    print("完成！请运行 insert_data.sql 文件。")

if __name__ == "__main__":
    if API_KEY == '你的_TMDB_API_KEY':
        print("错误：请先在代码中填入正确的 TMDB API KEY")
    else:
        run_etl()