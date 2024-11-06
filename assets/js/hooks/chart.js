import "../../vendor/lightweight-charts.standalone.production";

export const ChartHook = {
    mounted(...args) {
        console.log("chart component mounted", args)
        this.chart = LightweightCharts.createChart(this.el, {
            height: 576,
            autoSize: true,
            timeScale: {
                timeVisible: true,
                borderColor: "#94a3b8"
            },
            rightPriceScale: {
                borderColor: "#94a3b8"
            },
            grid: {
                vertLines: {
                    color: "#f3f4f6",
                },
                horzLines: {
                    color: "#f3f4f6",
                }
            },
            layout: {
                textColor: "#1e293b"
            }
        });
        this.bars = this.chart.addCandlestickSeries({
            borderVisible: false,
            upColor: '#0d9488',
            downColor: '#e11d48',
            wickUpColor: '#0d9488',
            wickDownColor: '#e11d48'
        });
        this.handleEvent("bars:update", this.handleBarsUpdate.bind(this))
        this.handleEvent("bars:init", this.handleBarsInit.bind(this))
    },

    updated() {
        console.log("Updates the chart el")
        this.chart = LightweightCharts.createChart(this.el, {
            height: 576,
            timeScale: {
                timeVisible: true,
            },
        });
        this.bars = this.chart.addCandlestickSeries();
    },

    handleBarsInit(payload) {
        console.log("Bars init messge", { payload })
        this.bars.setData(
            payload.bars.map(({ o, h, c, l, t }) => ({
                open: o,
                high: h,
                low: l,
                close: c,
                time: new Date(t).getTime() / 1000
            }))
        )
    },

    handleBarsUpdate(payload) {
        this.bars.update({ ...payload, time: new Date(payload.time).getTime() / 1000 })
    }

}