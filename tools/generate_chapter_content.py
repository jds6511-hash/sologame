"""장별 콘텐츠 표 검사·결정적 생성. --check는 어떤 파일도 쓰지 않는다."""
import argparse
import ast
import copy
import json
import re
from pathlib import Path
from gdtoolkit.formatter import format_code

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ['objective_kinds', 'objective_targets', 'objective_sources', 'objective_counts', 'objective_labels', 'objective_location_hints']


def load_manifest(root):
    files = sorted((root / 'godot/data/content').glob('*.json'))
    documents = [json.loads(path.read_text(encoding='utf-8-sig')) for path in files]
    base = next(doc for doc in documents if 'chapter' not in doc)
    return {'constants': copy.deepcopy(base['constants']), 'chapters': sorted((doc for doc in documents if 'chapter' in doc), key=lambda doc: doc['chapter'])}


def merged(data):
    constants = copy.deepcopy(data['constants'])
    for chapter in data['chapters']:
        for name, value in chapter['constants'].items():
            target = constants.setdefault(name, {})
            if set(target) & set(value):
                raise ValueError('중복 콘텐츠 ID: ' + name)
            target.update(value)
        for quest in chapter['quests']:
            if quest['quest_id'] in constants['QUESTS']:
                raise ValueError('중복 의뢰: ' + quest['quest_id'])
            constants['QUESTS'][quest['quest_id']] = quest['path']
    return constants


def local(root, path):
    if not path.startswith('res://') or '..' in Path(path).parts:
        raise ValueError('잘못된 리소스 경로: ' + path)
    return root / 'godot' / path.removeprefix('res://')


def read_quest(path):
    result = {'prerequisite': '', 'npc_id': 'yeoulmok_receptionist', 'accept_npc_id': ''}
    for key, raw in re.findall(r'^(\w+) = (.+)$', path.read_text(encoding='utf-8-sig'), re.M):
        if key == 'script':
            continue
        raw = re.sub(r'Array\[\w+\]\((.*)\)$', r'\1', raw)
        result[key] = ast.literal_eval(raw.replace('true', 'True').replace('false', 'False'))
    return result


def budget_reference(root, chapter):
    # 현행 머리말의 EXP 여유 증액은 S7/S11/S12만 해당한다. 3장은 기초 풀 유지.
    source = (root / 'docs/design/100-hour-progression-budget.md').read_text(encoding='utf-8')
    rows = [[cell.strip() for cell in line.strip().strip('|').split('|')] for line in source.splitlines() if line.startswith('|')]
    exp = next(row for row in rows if row[0] == str(chapter) and len(row) == 6)
    rep = next(row for row in rows if row[0] == 'R' + str(chapter) and len(row) == 8)
    count = next(row for row in rows if row[0].startswith(str(chapter) + ' ') and len(row) == 7)
    number = lambda value: int(value.replace(',', ''))
    report = number(exp[2])
    side = int(report * 0.4 + 0.5)
    return {'reward_exp': report, 'reward_gold': number(exp[5]),
            'reward_reputation': number(rep[6]) + number(rep[7]),
            'main_exp': report - side, 'side_exp': side,
            'main_reputation': number(rep[6]), 'side_reputation': number(rep[7]),
            'main_count': number(count[3]), 'side_count': number(count[4])}


def validate(data, root):
    c = merged(data)
    paths = list(c['QUESTS'].values())
    if len(paths) != len(set(paths)):
        raise ValueError('중복 의뢰 산출물 경로')
    for chapter in data['chapters']:
        for quest in chapter['quests']:
            path = quest['path']
            if not path.startswith('res://data/quests/') or not path.endswith('.tres'):
                raise ValueError('의뢰 산출물 경로 이탈')
            local(root, path)
    quests = {q['quest_id']: q for ch in data['chapters'] for q in ch['quests']}
    for id, path in c['QUESTS'].items():
        if id not in quests:
            quests[id] = read_quest(local(root, path))
    npcs = set(c['NPCS']) | set(c['EDGES'])
    for id, q in quests.items():
        if q['quest_id'] != id or q.get('prerequisite', '') not in set(quests) | {''}:
            raise ValueError('없는 선행 의뢰: ' + id)
        for key in ['npc_id', 'accept_npc_id']:
            if q.get(key, '') and q[key] not in npcs:
                raise ValueError('없는 NPC: ' + id)
        size = len(q['objective_counts'])
        if size == 0 or any(len(q[key]) != size for key in FIELDS):
            raise ValueError('목표 배열 길이: ' + id)
        for index in range(size):
            kind, target, source, count, label, hint = (q[key][index] for key in FIELDS)
            if type(count) is not int or count < 1 or not label:
                raise ValueError('목표 수량/표시: ' + id)
            if kind == 'KILL':
                if source in c.get('DEFENSE_WAVES', {}):
                    wave = c['DEFENSE_WAVES'][source]
                    valid = wave['content_id'] == target and wave['quest_id'] == id and wave['index'] == index and count <= len(wave['points'])
                elif source in c['HABITATS']:
                    valid = c['HABITATS'][source][3] == target
                elif source in c['MARKER_HABITATS']:
                    valid = c['MARKER_CONTENT_IDS'].get(source) == target
                else:
                    valid = False
            elif kind in ['REACH', 'INTERACT'] and target in c['SITES']:
                valid = c['SITES'][target][1:3] == [source, kind]
            else:
                valid = kind in ['TALK', 'REACH'] and target in npcs and source == ''
            if not valid:
                raise ValueError('없는 목표/source 또는 종류 불일치: ' + id)
        for key in ['reward_exp', 'reward_gold', 'reward_reputation']:
            if type(q.get(key, 0)) is not int or q.get(key, 0) < 0:
                raise ValueError('보상 형식: ' + id)
    for id in quests:
        seen = set()
        current = id
        while current:
            if current in seen:
                raise ValueError('선행 순환: ' + id)
            seen.add(current)
            current = quests[current].get('prerequisite', '')
    for ch in data['chapters']:
        reference = budget_reference(root, ch['chapter'])
        if any(ch['budget'][key] != value for key, value in reference.items() if not key.endswith('_count')):
            raise ValueError('현행 설계 예산과 표 불일치')
        for prefix, group in [('main', 'MQ-'), ('side', 'SQ-')]:
            if sum(q['quest_id'].startswith(group) for q in ch['quests']) != reference[prefix + '_count']:
                raise ValueError('메인/서브 의뢰 수 불일치')
        for key in ['reward_exp', 'reward_gold', 'reward_reputation']:
            if sum(q[key] for q in ch['quests']) != ch['budget'][key]:
                raise ValueError('장 보상 예산: ' + key)
        for prefix, group in [('main', 'MQ-'), ('side', 'SQ-')]:
            for key in ['exp', 'reputation']:
                if sum(q['reward_' + key] for q in ch['quests'] if q['quest_id'].startswith(group)) != ch['budget'][prefix + '_' + key]:
                    raise ValueError('메인/서브 예산: ' + prefix + '_' + key)
    for region, path in c['SCENES'].items():
        if not local(root, path).is_file() or region not in c['BOUNDS']:
            raise ValueError('없는 지역 씬: ' + region)
    initial_scene = (root / 'godot/scenes/world/eastern_frontier_starting_area.tscn').read_text(encoding='utf-8')
    for region, marker in c['MARKER_HABITATS'].values():
        parent, name = marker.rsplit('/', 1)
        if region not in c['SCENES'] or not re.search(r'\[node name="' + re.escape(name) + r'"[^\n]*parent="' + re.escape(parent) + '"', initial_scene):
            raise ValueError('없는 초기 몬스터 표식')
    def point(region, position):
        x, y = position['$vector']
        left, top, width, height = c['BOUNDS'][region]['$rect']
        if not left <= x < left + width or not top <= y < top + height:
            raise ValueError('지역 밖 좌표: ' + region)
    for region, position, title in c['NPCS'].values():
        point(region, position)
    for position, source, kind, title, region in c['SITES'].values():
        point(region, position)
    for source, dest, position, arrival, reverse in c['EDGES'].values():
        point(source, position); point(dest, arrival)
        if reverse not in c['EDGES'] or c['EDGES'][reverse][:2] != [dest, source]:
            raise ValueError('왕복 간선 오류')
    for wave in c.get('DEFENSE_WAVES', {}).values():
        for position in wave['points']:
            point(wave['region'], position)
        if not local(root, wave['stats']).is_file() or not (root / 'godot/scenes/monsters' / (wave['scene'] + '.tscn')).is_file():
            raise ValueError('없는 방어 몬스터 리소스')
    for rally in c.get('RALLIES', {}).values():
        point(rally['region'], rally['position'])
    for site in c.get('SITE_NOTICES', {}):
        if site not in c['SITES']:
            raise ValueError('없는 안내 표식')


def gd(value, indent=0):
    if isinstance(value, dict):
        for key, constructor in [('$vector', 'Vector2'), ('$vectori', 'Vector2i'), ('$rect', 'Rect2')]:
            if key in value:
                return constructor + '(' + ', '.join(map(str, value[key])) + ')'
        if not value:
            return '{}'
        return '{\n' + ''.join('\t' * (indent + 1) + json.dumps(key, ensure_ascii=False) + ': ' + gd(item, indent + 1) + ',\n' for key, item in value.items()) + '\t' * indent + '}'
    if isinstance(value, list):
        if not value:
            return '[]'
        compact = '[' + ', '.join(gd(item, indent) for item in value) + ']'
        if len(compact) + indent * 4 < 90 and '\n' not in compact:
            return compact
        return '[\n' + ''.join('\t' * (indent + 1) + gd(item, indent + 1) + ',\n' for item in value) + '\t' * indent + ']'
    return json.dumps(value, ensure_ascii=False)


FUNCTIONS = '''\n\nstatic func contains(id: String, point: Vector2) -> bool:
\treturn BOUNDS.has(id) and BOUNDS[id].has_point(point)


static func edge(source: String, destination: String) -> Array:
\tfor value in EDGES.values():
\t\tif value[0] == source and value[1] == destination:
\t\t\treturn value
\treturn []


static func next_gate(source: String, destination: String) -> String:
\tvar pending := [[source, ""]]
\tvar seen := {source: true}
\twhile not pending.is_empty():
\t\tvar current: Array = pending.pop_front()
\t\tfor id in EDGES:
\t\t\tvar value: Array = EDGES[id]
\t\t\tif value[0] != current[0] or seen.has(value[1]):
\t\t\t\tcontinue
\t\t\tvar first: String = id if current[1] == "" else current[1]
\t\t\tif value[1] == destination:
\t\t\t\treturn first
\t\t\tseen[value[1]] = true
\t\t\tpending.append([value[1], first])
\treturn ""
'''


def render(data):
    constants = merged(data)
    content = 'extends RefCounted\n## 자동 생성: tools/generate_chapter_content.py · 원본 godot/data/content/*.json\n'
    content += '\n'.join('const ' + key + ' := ' + gd(value) for key, value in constants.items()) + '\n' + FUNCTIONS
    output = {'godot/scripts/content/game_content.gd': format_code(content, max_line_length=100)}
    for ch in data['chapters']:
        for q in ch['quests']:
            text = '[gd_resource type="Resource" script_class="QuestData" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/quests/quest_data.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
            for key, value in q.items():
                if key == 'path':
                    continue
                rendered = gd(value)
                if isinstance(value, list):
                    rendered = 'Array[' + ('int' if key == 'objective_counts' else 'String') + '](' + rendered + ')'
                text += key + ' = ' + rendered + '\n'
            output['godot/' + q['path'].removeprefix('res://')] = text
    return output


def generate(data, root, destination, check=False):
    validate(data, root)
    output = render(data)
    for name in output:
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('생성 경로 이탈')
    if check:
        return all((destination / name).is_file() and (destination / name).read_text(encoding='utf-8') == text for name, text in output.items())
    for name, text in output.items():
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(text.encode('utf-8'))
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        valid = generate(load_manifest(ROOT), ROOT, ROOT, check=args.check)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, str(error) + '\n')
    if not valid:
        parser.exit(1, '생성 산출물이 원본 표와 다릅니다.\n')
    print('콘텐츠 표·예산·선행·source 검사 통과')


if __name__ == '__main__':
    main()



