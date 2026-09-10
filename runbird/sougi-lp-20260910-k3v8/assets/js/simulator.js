/* ================================================================
   総額シミュレーター
   ★P4/P5/P6: 下記の定数は True Heart の実額確認後に差し替える（現状=たたき）
   ================================================================ */
var PRICE = {           /* 基本料金（税込・円） */
  kasou:     165000,    /* 火葬式 */
  ichinichi: 385000,    /* 一日葬 */
  kazoku:    495000     /* 家族葬（二日葬） */
};
var LABEL = { kasou:"火葬式", ichinichi:"一日葬", kazoku:"家族葬" };
var STAY_PER_DAY = 20000;   /* ご安置＋ドライアイスの延長 1日あたり（要確認） */
var INCLUDED_DAYS = 1;      /* 基本料金に含まれる安置日数 */
var CITY = {                /* 火葬場の使用料・火葬料（要確認） */
  kawasaki: 0,
  yokohama: 12000,
  other:    50000
};
var RANGE_LOW = 0.95, RANGE_HIGH = 1.15;  /* 「約○〜○万円」の幅 */

var state = { plan:"kasou", city:"kawasaki", days:4 };

function yen(n){ return n.toLocaleString("ja-JP") + "円"; }
function man(n){ return (Math.round(n/1000)/10).toFixed(1).replace(/\.0$/,"") + "万円"; }

function render(){
  var base  = PRICE[state.plan];
  var extra = Math.max(0, state.days - INCLUDED_DAYS);
  var stay  = extra * STAY_PER_DAY;
  var city  = CITY[state.city];
  var total = base + stay + city;

  document.getElementById("daysOut").textContent = state.days + "日";
  document.getElementById("brkBase").textContent = yen(base);
  document.getElementById("brkDays").textContent = extra;
  document.getElementById("brkStay").textContent = yen(stay);
  document.getElementById("brkCity").textContent = yen(city);
  document.getElementById("simTotal").dataset.planLabel = LABEL[state.plan];
  document.getElementById("simTotal").textContent =
    "約 " + man(total*RANGE_LOW) + "〜" + man(total*RANGE_HIGH);
}

function bindSeg(id, key){
  var box = document.getElementById(id);
  box.addEventListener("click", function(e){
    var b = e.target.closest("button"); if(!b) return;
    Array.prototype.forEach.call(box.querySelectorAll("button"), function(x){
      x.setAttribute("aria-pressed", String(x === b));
    });
    state[key] = b.dataset[key];
    render();
  });
}
bindSeg("segPlan","plan");
bindSeg("segCity","city");
document.getElementById("days").addEventListener("input", function(e){
  state.days = parseInt(e.target.value, 10);
  render();
});

/* P7: 送信先確定までは実送信しない（テスト状態を維持） */
document.getElementById("contactForm").addEventListener("submit", function(e){
  e.preventDefault();
});
render();
