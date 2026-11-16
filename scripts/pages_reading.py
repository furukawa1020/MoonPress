"""Update archive and RSS settings without changing unrelated keys."""

from copy import deepcopy
import re

from pages_settings import update_settings


def set_size(settings, key, text):
    if not text:
        return
    if text == 'all':
        settings.pop(key, None)
    elif re.fullmatch(r'[1-9][0-9]{0,3}', text) and int(text) <= 1000:
        settings[key] = int(text)
    else:
        raise ValueError(f'{key} は1〜1000の整数、または all を指定してください。')


def read_settings(settings, inputs):
    original = deepcopy(settings)
    values = {key: value.strip() for key, value in inputs.items()}

    for key in ('page_size', 'tag_page_size'):
        set_size(settings, key, values.get(key, ''))

    layout = values.get('collection_layout', '')
    if layout == 'default':
        settings.pop('collection_layout', None)
    elif layout:
        settings['collection_layout'] = layout

    index = values.get('tag_index', 'keep')
    rss = values.get('rss', 'keep')
    if any(value not in ('keep', 'enable', 'disable') for value in (index, rss)):
        raise ValueError('有効・無効・変更なしのいずれかを選んでください。')
    if index == 'enable':
        settings['tag_index'] = True
    elif index == 'disable' and settings.get('tag_index', False):
        settings['tag_index'] = False

    rss_values = {
        key: value
        for key in ('title', 'description', 'limit')
        if (value := values.get('rss_' + key, ''))
    }
    if rss == 'disable':
        if rss_values:
            raise ValueError('RSSを無効にするときは配信タイトル・説明・件数を空欄にしてください。')
        settings.pop('feed', None)
    elif rss == 'enable' or rss_values:
        if rss == 'keep' and 'feed' not in settings:
            raise ValueError('RSSを有効にしてから配信設定を指定してください。')
        feed = settings.get('feed', {})
        for key in ('title', 'description'):
            if key in rss_values:
                feed[key] = rss_values[key]
        if not feed.get('title') or not feed.get('description'):
            raise ValueError('RSSの有効化にはタイトルと説明文を指定してください。')
        set_size(feed, 'limit', rss_values.get('limit', ''))
        settings['feed'] = feed

    return settings != original


def prepare(cli, site, fields, git):
    return update_settings(cli, site, git, lambda settings: read_settings(settings, fields))
