trigger JiraCommentEventTrigger on Jira_Comment__e (after insert) {
    for (Jira_Comment__e event : Trigger.New) {
        try {
            String raw = event.Comment__c;
            if (String.isBlank(raw)) continue;

            String parsed = raw;

            // 🔹 Étape 1 : Extraire les URLs pour ne pas qu’elles soient transformées
            Pattern urlPattern = Pattern.compile('(https?://[^\\s\\]\\)]+)');
            Matcher matcher = urlPattern.matcher(parsed);
            Map<String, String> urlPlaceholders = new Map<String, String>();
            Integer index = 0;
            while (matcher.find()) {
                String url = matcher.group(1);
                String placeholder = '[[LINK_' + index + ']]';
                urlPlaceholders.put(placeholder, url);
                parsed = parsed.replace(url, placeholder);
                index++;
            }

            // 🔹 Étape 2 : Traitement Markdown (sans toucher aux URLs)
            parsed = parsed.replaceAll('\\{color:[^}]+\\}', '');
            parsed = parsed.replaceAll('\\{color\\}', '');
            parsed = parsed.replaceAll('\\{panel:bgColor=[^}]+\\}', '');
            parsed = parsed.replaceAll('\\{panel\\}', '');
            parsed = parsed.replaceAll('\\*(.*?)\\*', '<b>$1</b>');
            parsed = parsed.replaceAll('_(.*?)_', '<i>$1</i>');
            parsed = parsed.replaceAll('\\+(.*?)\\+', '<u>$1</u>');
            parsed = parsed.replaceAll('\\-(.*?)\\-', '<s>$1</s>');
            parsed = parsed.replaceAll('\\[(.*?)\\|(https?://[^\\]]+)\\]', '<a href="$2">$1</a>');
            parsed = parsed.replaceAll('\\n+', '<p>&nbsp;</p>');
            parsed = parsed.replaceAll('!([^!\\|\\n]+)\\|[^!]*!', '<p>[Image: $1]</p>');
            parsed = parsed.replaceAll('!([^!\\n]+)!', '<p>[Image: $1]</p>');

            // 🔹 Étape 3 : Réinjecter les URLs originales
            for (String placeholder : urlPlaceholders.keySet()) {
                String originalUrl = urlPlaceholders.get(placeholder);
                parsed = parsed.replace(placeholder, originalUrl);
            }

            Boolean isRich = parsed != raw;

            // 🔹 Étape 4 : Création du FeedItem
            FeedItem fi = new FeedItem();
            fi.ParentId = event.RecordId__c;
            fi.Body = parsed;
            fi.IsRichText = isRich;
            insert fi;

            System.debug('✅ FeedItem créé avec succès pour : ' + event.RecordId__c);

        } catch (Exception e) {
            System.debug('❌ Erreur lors de l’insertion du FeedItem : ' + e.getMessage());
        }
    }
}