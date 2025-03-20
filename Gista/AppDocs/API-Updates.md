# Links API Documentation Update

## /links/store Endpoint

The API request body structure for the /links/store endpoint MUST use snake_case keys and proper nesting:

```json
{
  "user_id": "username_UUID",
  "link": {
    "category": "Technology",
    "url": "https://example.com/article",
    "title": "Article Title"
  },
  "auto_create_gist": true
}
```

### Common Issues:

1. Using camelCase keys ('userId', 'autoCreateGist') instead of snake_case ('user_id', 'auto_create_gist')
2. Using 'article' instead of 'link' for the nested object
3. Flattening properties that should be nested under 'link'

The server expects to access properties like 'request.link.category', so ensuring proper nesting is critical.
