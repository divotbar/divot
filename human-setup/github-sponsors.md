# GitHub Sponsors: the URL

Divot's README and landing page can link to a GitHub Sponsors profile. Neither
the Divot repo nor the RepoOS repo has a Sponsors setup to copy, so these steps
are GitHub's own flow. GitHub changes its screens often, so check the labels on
the page you see.

## Steps

1. Sign in to GitHub as the account that should receive sponsorships. The
   handoff lists the maintainer's GitHub account as `autogeosystems`. Confirm
   that is the right account before continuing; a personal account and the
   `divotbar` organisation are separate Sponsors profiles.
2. Go to https://github.com/sponsors and choose **Join the waitlist** or
   **Get started**, depending on what GitHub shows you.
3. Complete the onboarding. You will need to:
   - accept GitHub's Sponsors terms,
   - add a payout account (bank or Stripe), which GitHub requires before
     sponsorships can be paid out, and
   - confirm tax details.
   Only you can do these. Nothing in the repo can do them for you.
4. Once approved, your profile URL is `https://github.com/sponsors/<name>`,
   where `<name>` is the account or organisation name. Copy that URL.

## Tell the agents the URL

Paste the URL into the chat. The agents will add it to the public site and to
`.github/FUNDING.yml` on a task branch, not directly to `main`.

If you want the **Sponsor** button on the repository page, `FUNDING.yml` also
needs a line such as:

```yaml
github: [<name>]
```

The file goes at `.github/FUNDING.yml`. The `.github/` folder already exists in
the repo.

## Check it worked

- `https://github.com/sponsors/<name>` loads your Sponsors profile.
- The repository page shows a **Sponsor** button once `FUNDING.yml` is on
  `main`.
