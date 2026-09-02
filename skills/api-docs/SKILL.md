---
name: api-docs
description: Use when generating API documentation — OpenAPI/Swagger auto-generation from code, MkDocs Material, Docusaurus, Mintlify, Postman/Insomnia export. Trigger on "openapi", "swagger", "api docs", "mkdocs", "docusaurus", "/api-docs".
---

# api-docs

Auto-generate API documentation from source code atau manual specification. Local-first, version-controlled.

## Pendekatan

| Pendekatan | Tool | Best for |
|---|---|---|
| **Spec-first** | OpenAPI YAML/JSON hand-written | Public API, contract dengan client |
| **Code-first (Python)** | FastAPI → auto OpenAPI | FastAPI projects |
| **Code-first (Node)** | swagger-jsdoc / tsoa | Express/Fastify |
| **Code-first (Go)** | swag | Gin/Echo |
| **Static site** | MkDocs Material, Docusaurus, Mintlify | Long-form + API reference |
| **Hosted** | Stoplight, ReadMe, Mintlify cloud | Zero ops, $$ |

**Default FastAPI**: zero effort, OpenAPI auto-generated.  
**Default Node**: swagger-jsdoc inline JSDoc annotations.  
**Default Go**: swag dengan `// @Summary` annotations.

## FastAPI auto-OpenAPI

FastAPI generates OpenAPI spec at `/openapi.json` by default. Plus Swagger UI di `/docs`, ReDoc di `/redoc`. Customization:

```python
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi
import json

app = FastAPI(
    title="My API",
    description="API for X",
    version="1.0.0",
    contact={"name": "Fqih", "email": "mhmdfkih21@gmail.com"},
    license_info={"name": "MIT"},
    openapi_tags=[
        {"name": "users", "description": "User operations"},
        {"name": "auth", "description": "Authentication endpoints"},
    ],
)

# Add security scheme
from fastapi.security import OAuth2PasswordBearer
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/token")

@app.get("/users", tags=["users"], summary="List users")
async def list_users():
    """List all users with pagination.

    - **skip**: number of users to skip
    - **limit**: max users to return (max 100)
    """
    ...

# Export spec ke file
with open("openapi.json", "w") as f:
    json.dump(app.openapi(), f, indent=2)
```

## MkDocs Material setup

```bash
pip install mkdocs mkdocs-material
mkdocs new my-docs
```

`mkdocs.yml`:

```yaml
site_name: My API
site_url: https://docs.example.com
repo_url: https://github.com/Fqih/repo
repo_name: Fqih/repo

theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - search.highlight
    - content.code.copy

markdown_extensions:
  - admonition
  - pymdownx.highlight
  - pymdownx.superfences
  - pymdownx.tabbed
  - pymdownx.inlinehilite

plugins:
  - search
  - mkdocstrings:  # Python source doc integration
      handlers:
        python:
          paths: [src]
          options:
            docstring_style: google
            show_source: true

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - API Reference:
    - Users: api/users.md
    - Auth: api/auth.md
  - Guides:
    - Deployment: guides/deployment.md
```

Serve locally:
```bash
mkdocs serve  # http://localhost:8000
```

Build + deploy:
```bash
mkdocs build  # → site/
# Deploy:
# - GitHub Pages: mkdocs gh-deploy
# - Netlify: drag-drop site/ folder
# - Vercel: vercel deploy --prebuilt
```

## mkdocstrings (auto-generate dari docstrings)

Di `docs/api/users.md`:

```markdown
::: myapp.users
    options:
      show_source: true
      docstring_style: google
      members:
        - create_user
        - list_users
        - delete_user
```

Auto-renders signature + Google-style docstrings sebagai markdown.

## Docusaurus (React-based, JS-heavy)

```bash
npx create-docusaurus@latest my-docs classic
cd my-docs
npm start
```

Plus OpenAPI integration:
```bash
npm install docusaurus-plugin-openapi-docs
```

`docusaurus.config.js`:

```js
{
  plugins: [
    [
      'docusaurus-plugin-openapi-docs',
      {
        id: 'api',
        specPath: '../openapi.json',
        outputDir: 'docs/api',
      },
    ],
  ],
}
```

## Mintlify (hosted, paid, but best DX)

`mint.json`:

```json
{
  "name": "My API",
  "openapi": "openapi.json",
  "navigation": [
    {
      "group": "Getting Started",
      "pages": ["introduction", "authentication"]
    },
    {
      "group": "API",
      "pages": ["api/users", "api/auth"]
    }
  ]
}
```

Auto-generates from OpenAPI + allows custom MDX pages.

## Code-first: Node (swagger-jsdoc)

```javascript
// routes/users.js
/**
 * @openapi
 * /users:
 *   get:
 *     tags: [users]
 *     summary: List users
 *     responses:
 *       200:
 *         description: List of users
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/User'
 */
router.get('/users', listUsers);
```

```javascript
// swagger.js
const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const spec = swaggerJsdoc({
  definition: {
    openapi: '3.0.0',
    info: { title: 'My API', version: '1.0.0' },
  },
  apis: ['./routes/*.js'],
});

app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec));
```

## Code-first: Go (swag)

```go
// @Summary List users
// @Description Get list of users with pagination
// @Tags users
// @Param skip query int false "Skip count"
// @Param limit query int false "Limit (max 100)"
// @Success 200 {array} User
// @Router /users [get]
func ListUsers(c *gin.Context) {
    ...
}
```

```bash
swag init  # → docs/swagger.json
# Serve via gin-swagger
```

## CI/CD: keep docs in sync

```yaml
# .github/workflows/docs.yml
name: Build docs
on: [push]
jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install mkdocs mkdocs-material
      - run: mkdocs build --strict
      - uses: actions/deploy-pages@v4
        with:
          artifact: site
```

## Versioning

API versions di spec + URL:
- `/api/v1/users`
- `/api/v2/users` (breaking changes)

OpenAPI versions via info.version. Maintain changelog.md.

## OpenAPI spec tips

✅ Use `$ref` untuk reusable components (User schema, Error response)
✅ Add `example` ke semua fields (Swagger UI tampilkan)
✅ Define error responses (400, 401, 404, 500)
✅ Security schemes: Bearer JWT, OAuth2, API key
✅ Pagination: cursor-based atau offset-based, document choice
✅ Document rate limits + quotas

## Anti-patterns

❌ Hand-write OpenAPI untuk FastAPI (auto-generated lebih reliable)
❌ Docs repo terpisah dari code repo (drift inevitable)
❌ Skip error response docs (user bingung saat error)
❌ Publish docs tanpa versioning
❌ Inline JSDoc tanpa @openapi annotation (tidak ter-export)
❌ Hosting public docs untuk internal API (security leak)

## Integration dengan audit-workflow

Audit dimension "docs drift" cek apakah README references match actual files. Untuk API docs, validasi:
- All endpoint di OpenAPI ter-implement di code
- All routes terdaftar punya description
- OpenAPI valid JSON/YAML
- Docs site builds tanpa error (mkdocs --strict)

## Invokation

Auto-trigger:
- Edit FastAPI routes, Node route handlers, Go handlers
- Reference ke "openapi", "swagger", "api docs", "docs site"
- Slash command: `/api-docs`, `/gen-openapi`
