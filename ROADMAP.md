# OpenClaw Passive Income Supercharger Plan

## Status Key
- [x] Complete
- [ ] Not started
- [~] In progress

---

## Phase 0: Reliability & Cleanup [x]
- [x] Fix Edison's model (switched to Sonnet 4.5)
- [x] Prune crons from 21 to ~13
- [x] Increase IronHand Sprint timeout
- [x] Google dropped (banned from Cloud Code Assist API)
- [x] All agents on Anthropic (Claude Max $200/mo) + Ollama fallback

## Phase 1: Agent Architecture Restructure [x]
- [x] Magellan renamed to Quill (content engine)
- [x] Quill SOUL.md written (config/agents/quill-SOUL.md)
- [x] Edison refocused: sole focus IronHand SaaS
- [x] Final topology: Flounder(Opus4.6) / Edison(Sonnet4.5) / Quill(Sonnet4.5) / Atlas(Qwen3.5-9B) / JP(Qwen3.5-9B)
- [x] MiniMax M2.5 for Atlas/JP heartbeats

## Phase 2: VMwareMadeSimple Content Pipeline [~]

### Content Strategy - 4 High-Value Clusters

**Cluster 1: Broadcom/VMware Licensing** (highest search volume)
- [x] "Broadcom VMware Licensing Breakdown: What You're Actually Paying For Now" (published)
- [x] "vSphere Foundation vs Standard 2026: What You Actually Need Now" (published)
- [ ] "Should You Renew VMware or Switch? Decision Framework"

**Cluster 2: Migration Guides** (high affiliate potential)
- [ ] "VMware to Proxmox Migration: Complete Guide"
- [ ] "Best VMware Alternatives 2026: Honest Comparison"

**Cluster 3: Horizon/VDI** (active specialty)
- [ ] "Omnissa Horizon 2512 Deployment Guide"
- [ ] "NVIDIA vGPU Setup for Horizon: L40 Configuration"

**Cluster 4: Home Lab** (affiliate gold mine)
- [ ] "Best Mini PC for VMware Home Lab 2026"
- [ ] "VMware Home Lab on a Budget: Under $500"

### Publishing Pipeline
- [x] Static HTML + Tailwind site live on GitHub Pages
- [x] Custom domain vmwaremadesimple.com
- [x] Cloudflare DNS setup (nameserver propagation pending)
- [x] Article template created (article-template.html)
- [x] 2 articles published, placeholder cards removed
- [ ] Google Analytics (ID still placeholder G-2NDPP0ZTKC)
- [ ] Google Search Console setup
- [ ] Quill "Blog Sprint" cron (weekdays 11am EST) generating drafts
- [ ] Amazon Associates application (hardware affiliate links)
- [ ] After 15-20 articles: apply for Google AdSense
- Target: 5 articles/week, 20 articles in first month

## Phase 3: X/Twitter Account (overlaps Phase 2)
- [ ] Create X account (handle TBD)
- [ ] Python/Node.js posting script using X API v2 (Free tier: 1,500 tweets/mo)
- [ ] Content mix: 40% VMware/tech, 30% trading, 20% building in public, 10% personal
- [ ] "X Content Sprint" cron (daily 10am EST) - Quill generates 3-5 tweet drafts
- [ ] "X Post" cron (every 3-4 hours) - posts next queued tweet
- [ ] First week manual review, then auto-post

## Phase 4: IronHand Push to MVP (parallel)
- [ ] Complete roadmap (multi-tenant, Docker, backtester)
- [ ] Backtester critical - "backtest shows X% CAGR" is #1 marketing asset
- [ ] Deploy landing page to coreedgeinvesting.com
- [ ] Waitlist email collection (Buttondown or ConvertKit free tier)
- [ ] Once backtester done, Quill starts CoreEdgeInvesting content

## Phase 5: Monetization Activation (Days 30-60)
- [ ] VMwareMadeSimple: 20+ articles, AdSense + affiliate revenue
- [ ] CoreEdgeInvesting: 10+ articles, IronHand waitlist funnel
- [ ] X account: 300+ followers driving traffic to both blogs
- [ ] IronHand: Beta users (friends/family, Reddit r/LETFs)
- [ ] Consider: Paid VMware consulting via blog contact form ($250/hr)

---

## Parked Projects
| Project | Why | Revisit When |
|---------|-----|-------------|
| Superbot | Competes with OpenClaw for dev time | After IronHand ships |
| Discord Bot | No clear monetization | After X has traction |
| Prediction Markets | Regulatory risk | Never, or after stability |
| Freelance Scanning | Not passive income | If consulting demand via blog |

---

## Revenue Projections
| Month | VMwareMadeSimple | CoreEdge | IronHand | X/Twitter | Total |
|-------|-----------------|----------|----------|-----------|-------|
| 1 | $0 (building) | Not started | Dev | 100 followers | $0 |
| 3 | $50-200 | 10 articles | Waitlist | 600 followers | $50-200 |
| 6 | $300-800 | $100-300 | Beta $0-500 | 2K followers | $400-1,600 |
| 12 | $500-1,500 | $200-500 | $1K-5K | 5K+ followers | $1,700-7,000 |

## Verification Criteria
- Phase 0: All crons run without timeout for 48 hours
- Phase 1: Quill generates test article matching HTML template
- Phase 2: First 5 articles published, Search Console shows indexing
- Phase 3: X posting automatically 3-5 tweets/day for 7 consecutive days
- Phase 4: IronHand backtester produces results, landing page deployed
- Phase 5: Google Analytics shows organic traffic growth week-over-week
