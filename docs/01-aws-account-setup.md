# 01 - AWS Account Setup

## Create AWS Account

1. Go to <https://aws.amazon.com> and click "Create an AWS Account"
2. Enter root user email address and account name
3. Verify email, add payment method, complete identity verification
4. **Support plan**: Choose "Basic support - Free"
5. **Account plan**: Choose "Free" (6 months, $100-$200 in credits)

## Billing Protection (Do This First!)

### Zero Spend Budget

1. Search "Budgets" in AWS Console
2. Create budget → "Zero spend budget"
3. Add your email → alerts you when anything above $0.01 is spent

### Monthly Cost Budget

1. Create another budget → "Monthly cost budget"
2. Set amount to $10/month
3. Alerts trigger at 85% ($8.50) and 100% ($10)
4. **Note**: Budgets are alerts only - they don't stop spending
5. On the free plan, AWS cuts off access when credits run out (natural safety net)

### Enable Cost Explorer

1. Search "Cost Explorer" in AWS Console
2. Enable it (takes 24 hours to populate)
3. Check weekly to see what's costing money

## Key Info

- Free plan = hard cap at credit limit, account closes when credits/time expire
- Can upgrade to paid plan later when more confident
- MWAA has no free tier (~$0.05/hr for mw1.micro, ~$36/month if 24/7)
