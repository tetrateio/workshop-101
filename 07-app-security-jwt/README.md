# Overview
Previously we focused on service to service security based on workload identity and configured policies to restrict access based on the Workspace in addition to direct SPIFFE identity.  New we will focus on creating end-user authentication and authroization policy based on a JWT token, ensuring that only properly authenticated users that have the right permissions can use the Market Data service

## Request Authentication based on JWT
First, lets verify we can access the Market Data service via its external ingress endpoint:

```bash
curl -i https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

Even though request-level authentication was not provided, the call should succeed and return you a market quote.

This lab will demonstrate using [Auth0](https://auth0.com/) as an OIDC provider that will create JWT tokens for end user requests which will be authenticated and authorized at the Ingress Gateway or Application sidecar as a Policy Enforcement Point (PEP)

1.  Configure the `IngressGateway` for the market data service with request `authentication` settings to enforce JWT validation using `tctl apply`:

```bash
envsubst < 07-app-security-jwt/01-jwt-auth.yaml | tctl apply -f -   
``` 

Inspect the file `07-app-security-jwt/01-jwt-auth.yaml`.  This is nearly identical to the gateway we configured in the previous lab.  The important additional pieces are in the `authentication` and `authorization` sections:

```yaml
authentication:
  jwt:
    issuer: https://dev-8s63qgb5.us.auth0.com/
    jwksUri: https://dev-8s63qgb5.us.auth0.com/.well-known/jwks.json
authorization:
  local:
    rules:
    - name: allow-all
      from:
        - jwt:
            iss: https://dev-8s63qgb5.us.auth0.com/
            sub: "*"
      to:
        - paths: ["*"]
```

In the `authentication` section we are configuring how JWT tokens are going to be validated. There we configure the issuer for the tokens and the keystore with the keys to be used to validate the token signature.

In the `authorization` section we configure the AuthZ rules we want to apply to incoming traffic. In this example we are allowing all request as long as the JWT token is valid and signed by the issuer.

2. Verify that you no longer can invoke the market data service when you are unauthenticated:

- No authentication JWT provided:
```bash
curl -i https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

- Valid JWT not signed by issuer:
```bash
export TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0.NHVaYe26MbtOYhSKkoKYdFVomg4i8ZJd8_-RU8VNbftc4TSMb4bXP3l3YlNWACwyXPGffz5aXHc6lty1Y2t4SWRqGteragsVdZufDn5BlnJl9pdR_kdVFUsra2rWKEofkZeIC4yWytE58sMIihvo9H1ScmmVwBcQP6XETqYd0aSHp1gOa9RdUPDvoXQ5oqygTqVtxaDr6wUFKrKItgBMzWIdNZ6y7O9E0DhEPTbE9rfBo6KTFsHAZnMg4k68CDp2woYIaXbmYTWcvbzIuHO7_37GT79XdIwkm95QJ7hYC9RiwrV7mesbY4PAahERJawntho0my942XheVLmGwLMBkQ"
curl -i -H "Authorization: Bearer $TOKEN" https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

Both of these requests will result in an `HTTP 401` or `HTTP 403` response code.

Next we will obtain a valid JWT token from our OIDC provider, Auth0, and present this token to authenticate our request:

```bash
export TOKEN=$(curl --request POST \
  --url 'https://dev-8s63qgb5.us.auth0.com/oauth/token' \
  --data grant_type=password \
  --data client_id=$CLIENT_ID \
  --data client_secret=$CLIENT_SECRET \
  --data username=plain-user@tetrate.io --data password=t3trat3! | jq -r '.id_token')
echo "JWT Token:"
echo $TOKEN
curl -i -H "Authorization: Bearer $TOKEN" https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

## Request Authorization based on JWT claims
Our application ingress is now authenticating for any valid JWT token from our OIDC provider.  However, we do not have any policy for authorizing the correct users.  Within TSB establishing this policy is an easy task.

1.  Configure the `IngressGateway` for the market data service with request `authentication` and `authorization` policy to enforce JWT validation and rules based on the token claims using `tctl apply`:

```bash
envsubst < 07-app-security-jwt/02-jwt-authz.yaml | tctl apply -f -   
``` 

Inspect the file `07-app-security-jwt/02-jwt-authz.yaml`.  Focus in on the updated `authorization` section:

```yaml
authorization:
  local:
    rules:
    - name: only-market-data
      from:
        - jwt:
            iss: https://dev-8s63qgb5.us.auth0.com/
            sub: "*"
            other:
              https://tetrate.io/role: market-data
      to:
        - paths: ["*"]
```

In the `authorization` section we configure the AuthZ rules we want to apply to incoming traffic. In this example we will:

* Enforce the configured rule for all requests (`paths: ["*"]`).
* Require tokens to be issued by the configured issuer.
* Require `https://tetrate.io/role` claim in the token to have the value of `market-data`.

Once again, invoke the service with a JWT token from the same user, `plain-user@tetrate.io`:

```bash
export TOKEN=$(curl --request POST \
  --url 'https://dev-8s63qgb5.us.auth0.com/oauth/token' \
  --data grant_type=password \
  --data client_id=$CLIENT_ID \
  --data client_secret=$CLIENT_SECRET \
  --data username=plain-user@tetrate.io --data password=t3trat3! | jq -r '.id_token')
echo "JWT Token:"
echo $TOKEN
curl -i -H "Authorization: Bearer $TOKEN" https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

This call will fail with an `HTTP 403` response code and a message `RBAC: Access Denied`.  By decoding the JWT token we can verify that this user does not have the proper claim: `https://tetrate.io/role: market-data`:
```bash
./07-app-security-jwt/jwt-decode.sh
```
```bash
...
{
  "https://tetrate.io/role": "general", 
  "nickname": "plain-user",
  "name": "plain-user@tetrate.io",
  "picture": "https://s.gravatar.com/avatar/19edebeadd9274400dad859b6dba978d?s=480&r=pg&d=https%3A%2F%2Fcdn.auth0.com%2Favatars%2Fpl.png",
  "updated_at": "2022-02-11T20:07:23.844Z",
  "email": "plain-user@tetrate.io",
  "email_verified": false,
  "iss": "https://dev-8s63qgb5.us.auth0.com/",
  "sub": "auth0|6206b60059cf77006a55712b",
  "aud": "pNfSwmLegMhf13oJOJWM7fmee2xL7qYN",
  "iat": 1644610043,
  "exp": 1644646043
}
```

Now obtain a JWT token from our OIDC providerfor a user with the proper claims.  This time the API call will succeed:

```bash
export TOKEN=$(curl --request POST \
  --url 'https://dev-8s63qgb5.us.auth0.com/oauth/token' \
  --data grant_type=password \
  --data client_id=$CLIENT_ID \
  --data client_secret=$CLIENT_SECRET \ \
  --data username=market-data-user@tetrate.io --data password=t3trat3! | jq -r '.id_token')
echo "JWT Token:"
echo $TOKEN
curl -i -H "Authorization: Bearer $TOKEN" https://quotes.$PREFIX.workshop.cx.tetrate.info/v1/quotes\?q\=GOOG
```

By decoding the JWT token we can verify that this user has the proper claim: `https://tetrate.io/role: market-data`:
```bash
./07-app-security-jwt/jwt-decode.sh
```
```bash
...
{
  "https://tetrate.io/role": "market-data",
  "nickname": "market-data-user",
  "name": "market-data-user@tetrate.io",
  "picture": "https://s.gravatar.com/avatar/a731eee74307d53bd2e2d945761dd5e3?s=480&r=pg&d=https%3A%2F%2Fcdn.auth0.com%2Favatars%2Fma.png",
  "updated_at": "2022-02-11T20:30:54.514Z",
  "email": "market-data-user@tetrate.io",
  "email_verified": false,
  "iss": "https://dev-8s63qgb5.us.auth0.com/",
  "sub": "auth0|6206c73b59cf77006a5575b3",
  "aud": "pNfSwmLegMhf13oJOJWM7fmee2xL7qYN",
  "iat": 1644611454,
  "exp": 1644647454
}
```