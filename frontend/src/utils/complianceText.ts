const COMPLIANCE_REPLACEMENTS: Array<[RegExp, string]> = [
  [/token\s*售卖/gi, '模型调用服务'],
  [/gpt\s*token/gi, '编程模型调用配额'],
  [/官方充值/gi, '服务开通'],
  [/代充/gi, '平台服务'],
  [/api\s*key\s*售卖/gi, '接口接入服务'],
  [/共享\s*key/gi, '团队调用权限'],
  [/openai\s*余额/gi, '模型调用配额'],
  [/deepseek\s*余额/gi, '模型调用配额'],
  [/模型代币/gi, '模型调用配额'],
  [/低价官方额度/gi, '平台调用套餐'],
  [/授权代理/gi, '平台服务方案'],
  [/token sale/gi, 'model access service'],
  [/gpt\s*token/gi, 'coding model quota'],
  [/official top-?up/gi, 'service activation'],
  [/api\s*key\s*sale/gi, 'API access service'],
  [/shared\s*key/gi, 'team access'],
  [/openai\s*balance/gi, 'model access quota'],
  [/deepseek\s*balance/gi, 'model access quota'],
  [/model token/gi, 'model access quota'],
  [/low-cost official credits?/gi, 'platform service package'],
  [/authorized agent/gi, 'platform service provider'],
]

export function sanitizeComplianceText(input: string | null | undefined): string {
  let output = input ?? ''
  for (const [pattern, replacement] of COMPLIANCE_REPLACEMENTS) {
    output = output.replace(pattern, replacement)
  }
  return output
}
