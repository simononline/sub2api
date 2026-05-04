<!--
 * @Author: HuangQS 564479745@qq.com
 * @Date: 2026-05-05 01:35:40
 * @LastEditors: HuangQS 564479745@qq.com
 * @LastEditTime: 2026-05-05 02:11:58
 * @FilePath: \sub2api\frontend\src\components\marketing\HeartfeltIntro.vue
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
-->
<template>
  <section
    :id="sectionId"
    class="rounded-lg border border-gray-200 bg-white/95 p-5 shadow-card dark:border-dark-800 dark:bg-dark-900/90 md:p-6"
  >
    <div class="mb-5 flex items-center gap-3">
      <div class="grid h-11 w-11 place-items-center rounded-lg border border-primary-200 bg-primary-50 text-primary-700 dark:border-primary-500/20 dark:bg-primary-950/30 dark:text-primary-200">
        <Icon name="book" size="lg" />
      </div>
      <div>
        <h3 class="text-xl font-semibold text-gray-950 dark:text-white">心里话</h3>
        <p class="text-sm text-gray-500 dark:text-dark-400">从自用到合购，只想把成本摊薄，把稳定留给真正需要的人。</p>
      </div>
    </div>

    <div class="space-y-5 text-sm leading-8 text-gray-700 dark:text-dark-200 md:text-base md:leading-8">
      <p>
        这个网站最开始不是为了做成什么平台，而是<span class="rounded bg-primary-50 px-1.5 py-0.5 font-semibold text-primary-800 dark:bg-primary-500/15 dark:text-primary-100">我自己在工作和日常里会用到</span>的中转服务。服务器、域名、账号、Docker 和线路都是一边用一边学着搭起来的，后来开放给项目组和团队同学一起用；有了专业运维同学的支持后，才安心、稳定地跑了几个月。现在如果有人愿意加入合购，既能把<span class="underline decoration-wavy decoration-amber-400 underline-offset-4 dark:decoration-amber-300">成本摊薄一点</span>，也能让和我一样需要<span class="text-lg font-semibold text-primary-700 dark:text-primary-200 md:text-xl">稳定工具</span>的人少走几段弯路。
      </p>
      <p>
        在此之前，我真的被上游中转站折腾到心累。很多服务又贵又难用
        <a
          href="https://www.helpaio.com/transit"
          target="_blank"
          rel="noopener noreferrer"
          class="mx-1 inline-flex align-middle items-center justify-center gap-1 rounded px-1.5 py-0.5 text-sm font-semibold leading-5 text-primary-700 underline decoration-primary-300 underline-offset-4 transition-colors hover:bg-primary-50 hover:text-primary-800 focus:outline-none focus:ring-2 focus:ring-primary-500/40 dark:text-primary-200 dark:decoration-primary-400 dark:hover:bg-primary-500/10 dark:hover:text-primary-100"
        >
          参考
          <Icon name="externalLink" size="xs" />
        </a>这个页面就能看到知名的中转站有多贵，不知名的平台充了钱还可能跑路；为了找一个能长期用、<span class="underline decoration-wavy decoration-rose-400 underline-offset-4 dark:decoration-rose-300">关键时刻不掉链子</span>的渠道，我自己也花了不少钱去试：今天还好好的，明天突然不可用；特别是在<span class="rounded bg-rose-50 px-1.5 py-0.5 font-semibold text-rose-800 dark:bg-rose-500/15 dark:text-rose-100">去年年底团队任务很紧</span>，上游却突然失联搞得我很难受；用 Cursor 时总担心<span class="text-lg font-semibold text-amber-700 dark:text-amber-200 md:text-xl">额度</span>，用 Copilot 又受上下文限制，GLM Coding Plan 贵且慢，最后只能放弃。
      </p>
      <p>
        现在很多平台已经不太愿意做<span class="rounded bg-emerald-50 px-1.5 py-0.5 font-semibold text-emerald-800 dark:bg-emerald-500/15 dark:text-emerald-100">月套餐</span>了，更多是按额度、按用量付费。按量本身不是不好，问题是太多地方不透明：有的会暗改价格，表面显示 0.005 刀，实际<span class="underline decoration-wavy decoration-amber-400 underline-offset-4 dark:decoration-amber-300">消耗快得像倒水</span>；也会让人担心聊天记录被二次利用。所以我才决定自己实打实买 Pro 账号组成号池（以前也额外折腾过一段 Free 账号号池，但最后都死掉了）。现在能继续跑下来，<span class="text-lg font-semibold text-primary-700 dark:text-primary-200 md:text-xl">大家参加的人越多，这个生态圈就越稳定</span>，也不用总担心上游号炸了、自己的 Key 炸了。我是真心希望：愿意合购的人，至少能稳定地用起来。<span class="rounded bg-amber-50 px-1.5 py-0.5 font-semibold text-amber-900 dark:bg-amber-500/15 dark:text-amber-100">众人拾柴火焰高</span>，这句话放在这里很贴切。
      </p>
      <p>
        说实话，这个平台并不是只想着赚钱。对我来说，一是<span class="text-lg font-semibold text-emerald-700 dark:text-emerald-200 md:text-xl">保证大家稳定访问</span>，二是<span class="underline decoration-wavy decoration-primary-400 underline-offset-4 dark:decoration-primary-300">把平均价格摊下来</span>，三是把它当作一个长期学习和实践的项目。不需要总操心银行卡付不了、黑 Key 导致封号（以前我也买过黑 Key，被封过几次还不给质保，后来就老实了）、来来回回反复折腾。只要这个 Pro 号池还能健康运转，参与的人越多，整个平台就越稳，我会根据用量调增加Pro账号，都是<span class="text-lg font-semibold text-amber-700 dark:text-amber-200 md:text-xl">官方渠道</span>，所以大家也不用总担心某天突然用不了。
      </p>
      <p>
        联系的 Q 群 <span class="rounded bg-primary-100 px-1.5 py-0.5 font-mono text-base font-semibold text-primary-800 dark:bg-primary-500/20 dark:text-primary-100">1041906235</span>，现在已经开到第三个了。平时我也会看 Pro 号池额度剩余和平台状态，偶尔当个权限狗给大家<span class="underline decoration-wavy decoration-emerald-400 underline-offset-4 dark:decoration-emerald-300">发点福利、批量加额度</span>(大手一挥很爽)。哪怕只是参与小套餐也没关系，我更希望这个自己搭起来的网站<span class="text-lg font-semibold text-primary-700 dark:text-primary-200 md:text-xl">能够活得更久</span>，而不是某一天轰然倒塌。
      </p>
      <p>
        最后：目前暂时还没有 Claude，因为我们公司团队里主要使用 Codex 系，所以现在优先把<span class="rounded bg-sky-50 px-1.5 py-0.5 font-semibold text-sky-800 dark:bg-sky-500/15 dark:text-sky-100"> OpenAI 号池</span>维护稳定。但如果以后想用 Claude 的小伙伴多起来了，人够了我们就再开一车，这样大家消费起来也更稳定、更便宜。总归一句话：这个站<span class="underline decoration-wavy decoration-amber-400 underline-offset-4 dark:decoration-amber-300">就像吃自助餐，海鲜鲍鱼吃到了，人均下来也不贵</span>；我也能继续学习新东西，这就值得继续折腾。
      </p>
      <figure class="space-y-3">
        <img
          src="/docs/pro-pool.png"
          alt="现在的 Pro 号池"
          class="w-full rounded-lg border border-gray-200 bg-white object-contain shadow-sm dark:border-dark-700 dark:bg-dark-950"
        >
        <figcaption class="text-center text-sm font-semibold text-gray-600 dark:text-dark-300">
          现在的 Pro 号池
        </figcaption>
      </figure>
    </div>
  </section>
</template>

<script setup lang="ts">
import Icon from '@/components/icons/Icon.vue'

defineProps<{
  sectionId?: string
}>()
</script>
