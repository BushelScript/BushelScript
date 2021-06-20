<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>{{ site.github.project_title }}</title>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        {% for release in site.github.releases %}
            {% unless release.draft %}
                {% unless release.prerelease and page.release_only %}
                    {% assign asset = release.assets.first %}
                    {% assign project_name = 'BushelScript' %}
                    {% assign asset_name_rest = asset.name | replace_first:project_name,'' %}
                    {% if asset and asset_name_rest contains '.v' %}
                        <item>
                            <title>{{ release.name | escape }}</title>
                            <description>
                              <![CDATA[
                                {% include release-notes-style.html %}
                                {{ release.body | markdownify }}
                              ]]>
                            </description>
                            <pubDate>{{ release.published_at | date_to_rfc822 | escape }}</pubDate>
                            {% assign build_nums = asset_name_rest | replace_first:'.v','' | replace_first:'.b',',' | remove_first:'.dmg' | remove_first:'.zip' | split:',' %}
                            {% if build_nums.size == 2 %}
                                {% assign version = build_nums[1] %}
                                {% assign short_version = release.tag_name | remove_first:'v' %}
                            {% else %}
                                {% assign version = release.tag_name | remove_first:'v' %}
                            {% endif %}
                            <enclosure
                                url="{{ asset.browser_download_url | escape }}"
                                sparkle:version="{{ version | escape }}"
                                {% if short_version %}sparkle:shortVersionString="{{ release.tag_name | remove_first:'v' | escape }}"{% endif %}
                                length="{{ asset.size | escape }}"
                                type="application/octet-stream" />
                        </item>
                    {% endif %}
                {% endunless %}
            {% endunless %}
        {% endfor %}
    </channel>
</rss>
